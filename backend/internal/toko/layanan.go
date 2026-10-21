package toko

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"regexp"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// aturan bisnis yang sama kayak di aplikasi (domain/aturan/pembayaran.dart)
const (
	persenBiayaLayanan = 10
	// F-40: porsi ditahan selama ini sebelum pesanan batal sendiri
	menitBatasBayar = 15
	maksJumlah      = 99
	maksJenisPaket  = 10
)

var (
	metodeBayar   = []string{"qris", "gopay", "va_bca", "va_mandiri", "va_bri", "va_bni"}
	kategoriPaket = []string{"Hidangan utama", "Pastry & roti", "Buffet hotel", "Dessert", "Minuman"}
	// zona waktu Samarinda. pakai zona tetap biar ga butuh tzdata
	wita = time.FixedZone("WITA", 8*60*60)
)

// Layanan aturan bisnis gerai, paket, dan pesanan
type Layanan struct {
	Store Store
	// Jam waktu sekarang, bisa diganti di tes
	Jam func() time.Time
	// JamDemo kalau diisi, "jam berapa sekarang" dikunci ke menit ini (misal 16*60+20),
	// sama kayak jamSekarang di aplikasi demo. batas bayar tetap pakai waktu asli
	JamDemo *int
	// PencairanUji pencairan harian langsung dianggap berhasil karena belum ada
	// transfer bank beneran. di production status awalnya Diproses
	PencairanUji bool
	// QRISStatis isi QRIS statis milik Sisa Rasa (env QRIS_STATIS). kalau diisi,
	// pesanan QRIS dapet QR asli dengan nominal pesanan di dalamnya. kosong = QR tiruan
	QRISStatis string
	// FotoSah ngecek URL foto unggahan (foto.Penyimpanan.Sah). nil = cuma foto bawaan
	FotoSah func(url string) bool
	// Gerbang penyedia pembayaran asli (Midtrans). nil = mode uji
	Gerbang Gerbang
}

func (l *Layanan) sekarang() time.Time {
	if l.Jam != nil {
		return l.Jam()
	}
	return time.Now()
}

// menit dari tengah malam WITA, buat dibandingin sama jam ambil paket
func (l *Layanan) menitSekarang() int {
	if l.JamDemo != nil {
		return *l.JamDemo
	}
	t := l.sekarang().In(wita)
	return t.Hour()*60 + t.Minute()
}

func galat(kode int, pesan string) error { return httpx.NewGalat(kode, pesan) }

// polaID bentuk UUID. id dari URL dicek dulu biar yang ngawur langsung 404,
// ga sampai ke database
var polaID = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func idSah(id string) bool { return polaID.MatchString(id) }

// polaFotoBawaan foto contoh yang ikut di aplikasi (assets/images/paket)
var polaFotoBawaan = regexp.MustCompile(`^assets/images/paket/[a-z0-9_]+\.jpg$`)

var (
	errBukanPembeli = galat(http.StatusForbidden, "Fitur ini khusus akun pembeli.")
	errBukanMitra   = galat(http.StatusForbidden, "Fitur ini khusus akun mitra.")
	errTidakAda     = galat(http.StatusNotFound, "Data tidak ditemukan.")
)

// ---------- paket ----------

// DaftarPaket semua paket yang belum dihapus. aplikasi yang nyaring jam tutup,
// karena jam demo di aplikasi bisa beda sama jam server
// [a] akun yang lagi masuk (boleh kosong buat tamu). mitra ikut liat paketnya
// sendiri walau gerainya belum diverifikasi
func (l *Layanan) DaftarPaket(ctx context.Context, a akun.Akun) ([]Paket, error) {
	idMitra := ""
	if a.Peran == "mitra" {
		idMitra = a.ID
	}
	return l.Store.SemuaPaket(ctx, idMitra)
}

func (l *Layanan) PaketSaya(ctx context.Context, a akun.Akun) ([]Paket, error) {
	if a.Peran != "mitra" {
		return nil, errBukanMitra
	}
	return l.Store.PaketMitra(ctx, a.ID)
}

func (l *Layanan) cekIsian(isi *IsianPaket) error {
	isi.Nama = strings.TrimSpace(isi.Nama)
	isi.Deskripsi = strings.TrimSpace(isi.Deskripsi)
	switch {
	case isi.Nama == "" || len([]rune(isi.Nama)) > 80:
		return galat(http.StatusUnprocessableEntity, "Nama paket wajib diisi, paling panjang 80 huruf.")
	case len([]rune(isi.Deskripsi)) > 200:
		return galat(http.StatusUnprocessableEntity, "Deskripsi paling panjang 200 huruf.")
	case !slices.Contains(kategoriPaket, isi.Kategori):
		return galat(http.StatusUnprocessableEntity, "Pilih kategori paket.")
	case isi.HargaAsli <= 0 || isi.HargaAsli > 10_000_000:
		return galat(http.StatusUnprocessableEntity, "Harga asli tidak valid.")
	case isi.HargaDiskon < 0 || isi.HargaDiskon >= isi.HargaAsli:
		// F-16
		return galat(http.StatusUnprocessableEntity, "Harga diskon harus lebih murah dari harga asli.")
	case isi.TotalPorsi <= 0 || isi.TotalPorsi > 999:
		// F-17
		return galat(http.StatusUnprocessableEntity, "Jumlah porsi harus 1 sampai 999.")
	case isi.Mulai < 0 || isi.Tutup > 24*60 || isi.Mulai >= isi.Tutup:
		return galat(http.StatusUnprocessableEntity, "Jam tutup ambil harus setelah jam buka.")
	}
	switch {
	case isi.Foto == "":
		isi.Foto = "assets/images/paket/buffet_hotel.jpg"
	case !polaFotoBawaan.MatchString(isi.Foto) && (l.FotoSah == nil || !l.FotoSah(isi.Foto)):
		// cuma foto bawaan aplikasi atau unggahan ke server ini, bukan URL bebas
		return galat(http.StatusUnprocessableEntity, "Foto paket tidak valid. Unggah ulang fotonya.")
	}
	return nil
}

func (l *Layanan) BuatPaket(ctx context.Context, a akun.Akun, isi IsianPaket) (Paket, error) {
	if a.Peran != "mitra" {
		return Paket{}, errBukanMitra
	}
	if err := l.cekIsian(&isi); err != nil {
		return Paket{}, err
	}
	return l.Store.BuatPaket(ctx, a.ID, isi)
}

func (l *Layanan) UbahPaket(ctx context.Context, a akun.Akun, id string, isi IsianPaket) (Paket, error) {
	if !idSah(id) {
		return Paket{}, errTidakAda
	}
	if a.Peran != "mitra" {
		return Paket{}, errBukanMitra
	}
	if err := l.cekIsian(&isi); err != nil {
		return Paket{}, err
	}
	return tanganiTidakAda(l.Store.UbahPaket(ctx, a.ID, id, isi))
}

// AturSisa F-44: mitra ubah sisa porsi langsung
func (l *Layanan) AturSisa(ctx context.Context, a akun.Akun, id string, sisa int) (Paket, error) {
	if !idSah(id) {
		return Paket{}, errTidakAda
	}
	if a.Peran != "mitra" {
		return Paket{}, errBukanMitra
	}
	if sisa < 0 {
		return Paket{}, galat(http.StatusUnprocessableEntity, "Sisa porsi tidak boleh minus.")
	}
	return tanganiTidakAda(l.Store.AturSisa(ctx, a.ID, id, sisa))
}

// AturAktif F-45
func (l *Layanan) AturAktif(ctx context.Context, a akun.Akun, id string, aktif bool) (Paket, error) {
	if !idSah(id) {
		return Paket{}, errTidakAda
	}
	if a.Peran != "mitra" {
		return Paket{}, errBukanMitra
	}
	return tanganiTidakAda(l.Store.AturAktif(ctx, a.ID, id, aktif))
}

func (l *Layanan) HapusPaket(ctx context.Context, a akun.Akun, id string) error {
	if !idSah(id) {
		return errTidakAda
	}
	if a.Peran != "mitra" {
		return errBukanMitra
	}
	_, err := tanganiTidakAda(Paket{}, l.Store.HapusPaket(ctx, a.ID, id))
	return err
}

// AturGerai F-51: tutup / buka gerai sementara
func (l *Layanan) AturGerai(ctx context.Context, a akun.Akun, tutup bool) error {
	if a.Peran != "mitra" {
		return errBukanMitra
	}
	return l.Store.AturGerai(ctx, a.ID, tutup)
}

func tanganiTidakAda[T any](v T, err error) (T, error) {
	if errors.Is(err, ErrTidakAda) {
		return v, errTidakAda
	}
	return v, err
}

// ---------- pesanan ----------

// sidik isi pesanan, buat ngecek request ulang dengan kunci sama isinya juga sama
func sidik(isi map[string]int, metode string) string {
	id := make([]string, 0, len(isi))
	for k := range isi {
		id = append(id, k)
	}
	sort.Strings(id)
	var b strings.Builder
	for _, k := range id {
		fmt.Fprintf(&b, "%s:%d,", k, isi[k])
	}
	return b.String() + "|" + metode
}

// BuatPesanan F-07 s.d. F-10, F-23, F-40. [kunci] dari header Idempotency-Key:
// aplikasi bikin satu kunci per tombol Bayar, jadi kalau request-nya dikirim ulang
// (sinyal putus, tombol kepencet dua kali) pesanannya ga dobel dan stok ga kepotong dua kali
func (l *Layanan) BuatPesanan(ctx context.Context, a akun.Akun, isi map[string]int, metode, kunci string) (Pesanan, bool, error) {
	if a.Peran != "pembeli" {
		return Pesanan{}, false, errBukanPembeli
	}
	kunci = strings.TrimSpace(kunci)
	if len(kunci) < 8 || len(kunci) > 100 {
		return Pesanan{}, false, galat(http.StatusBadRequest, "Header Idempotency-Key wajib diisi.")
	}
	if !slices.Contains(metodeBayar, metode) {
		return Pesanan{}, false, galat(http.StatusUnprocessableEntity, "Pilih metode pembayaran.")
	}
	if len(isi) == 0 || len(isi) > maksJenisPaket {
		return Pesanan{}, false, galat(http.StatusUnprocessableEntity, "Keranjang kosong.")
	}
	for id, j := range isi {
		if !idSah(id) {
			return Pesanan{}, false, galat(http.StatusConflict, "Ada paket yang sudah tidak tersedia. Muat ulang daftar paket.")
		}
		if j <= 0 || j > maksJumlah {
			return Pesanan{}, false, galat(http.StatusUnprocessableEntity, "Jumlah porsi tidak valid.")
		}
	}

	baru := PesananBaru{
		IDPembeli: a.ID, NamaPembeli: namaSingkat(a.Nama),
		Isi: isi, Metode: metode, Kunci: kunci, Sidik: sidik(isi, metode),
	}
	// nomor pesanan acak, kalau kebetulan kembar diulang
	for range 5 {
		p, dibuat, err := l.Store.BuatPesanan(ctx, baru, func(paket []Paket) (Pesanan, error) {
			return l.susun(baru, paket)
		})
		if errors.Is(err, ErrBentrok) {
			continue
		}
		if err == nil && !dibuat && p.sidik != baru.Sidik {
			return Pesanan{}, false, galat(http.StatusUnprocessableEntity,
				"Kunci pesanan ini sudah dipakai untuk pesanan lain.")
		}
		if err != nil {
			return p, dibuat, err
		}
		// tagihan dari penyedia diminta di luar transaksi, biar stok ga kekunci
		// selama nunggu jawaban. kalau gagal, request yang diulang (kunci sama)
		// bakal nyoba bikin tagihannya lagi
		p, err = l.pastikanTagihan(ctx, p)
		return p, dibuat, err
	}
	return Pesanan{}, false, errors.New("nomor pesanan bentrok terus")
}

// susun ngecek paket yang udah dikunci Store lalu ngitung isi pesanan.
// dipanggil di dalam transaksi, jadi sisa porsi yang dibaca di sini pasti terbaru
func (l *Layanan) susun(baru PesananBaru, paket []Paket) (Pesanan, error) {
	if len(paket) != len(baru.Isi) {
		return Pesanan{}, galat(http.StatusConflict, "Ada paket yang sudah tidak tersedia. Muat ulang daftar paket.")
	}
	menit := l.menitSekarang()
	sekarang := l.sekarang()
	pertama := paket[0]
	p := Pesanan{
		IDAkun: baru.IDPembeli, IDMitra: pertama.IDMitra,
		NamaPembeli: baru.NamaPembeli, Mitra: pertama.Mitra,
		Alamat: pertama.Alamat, Foto: pertama.Foto,
		Mulai: pertama.Mulai, Tutup: pertama.Tutup,
		Status: MenungguBayar, Metode: baru.Metode,
		Dipesan: menit, Dibuat: sekarang,
		kunci: baru.Kunci, sidik: baru.Sidik,
	}
	for _, pk := range paket {
		j := baru.Isi[pk.ID]
		switch {
		case pk.IDMitra != pertama.IDMitra:
			// F-07: satu pesanan cuma dari satu mitra, karena diambil langsung di tempat
			return Pesanan{}, galat(http.StatusUnprocessableEntity, "Satu pesanan hanya bisa dari satu mitra.")
		case pk.StatusGerai != GeraiTerverifikasi:
			// F-37: mitra yang belum diverifikasi / dinonaktifkan ga bisa nerima pesanan
			return Pesanan{}, galat(http.StatusConflict, pk.Mitra+" belum bisa menerima pesanan.")
		case pk.Nonaktif || pk.GeraiTutup || pk.dihapus:
			return Pesanan{}, galat(http.StatusConflict, pk.Nama+" sedang tidak dijual.")
		case pk.Tutup <= menit:
			// F-25
			return Pesanan{}, galat(http.StatusConflict, "Jam ambil "+pk.Nama+" sudah lewat.")
		case pk.SisaPorsi < j:
			// F-28
			return Pesanan{}, galat(http.StatusConflict,
				fmt.Sprintf("Sisa %s tinggal %d porsi.", pk.Nama, pk.SisaPorsi))
		}
		p.Isi = append(p.Isi, IsiPesanan{
			IDPaket: pk.ID, Nama: pk.Nama, Deskripsi: pk.Deskripsi, Foto: pk.Foto,
			Harga: pk.HargaDiskon, HargaAsli: pk.HargaAsli, Jumlah: j,
		})
		p.Subtotal += pk.HargaDiskon * j
		p.HargaNormal += pk.HargaAsli * j
		p.Porsi += j
		// pesanan ikut jam tutup paling awal di keranjang
		p.Tutup = min(p.Tutup, pk.Tutup)
	}
	p.BiayaLayanan = (p.Subtotal*persenBiayaLayanan + 50) / 100
	p.Total = p.Subtotal + p.BiayaLayanan
	p.Hemat = p.HargaNormal - p.Subtotal

	// F-40: ditahan 15 menit, tapi ga boleh lewat jam tutup ambil
	batas := min(menitBatasBayar, max(1, p.Tutup-menit))
	p.BatasBayar = sekarang.Add(time.Duration(batas) * time.Minute)
	p.BatasMenit = menit + batas

	nomor, err := acak("0123456789", 4)
	if err != nil {
		return Pesanan{}, err
	}
	p.Nomor = "SR-" + sekarang.In(wita).Format("060102") + nomor
	if p.ID, err = idBaru(); err != nil {
		return Pesanan{}, err
	}
	p.Tagihan = l.tagihan(p.ID, p.Total, p.Metode)
	return p, nil
}

// Daftar pesanan milik akun. pembeli: pesanannya sendiri.
// mitra: pesanan yang masuk ke gerainya, yang belum dibayar ga ikut
func (l *Layanan) Daftar(ctx context.Context, a akun.Akun) ([]Pesanan, error) {
	l.Bersihkan(ctx)
	switch a.Peran {
	case "pembeli":
		return l.Store.PesananPembeli(ctx, a.ID)
	case "mitra":
		semua, err := l.Store.PesananMitra(ctx, a.ID)
		if err != nil {
			return nil, err
		}
		hasil := make([]Pesanan, 0, len(semua))
		for _, p := range semua {
			if p.DibayarPada != nil {
				hasil = append(hasil, p)
			}
		}
		return hasil, nil
	}
	return nil, errTidakAda
}

// Satu pesanan, cuma buat pembeli atau mitranya sendiri
func (l *Layanan) Satu(ctx context.Context, a akun.Akun, id string) (Pesanan, error) {
	if !idSah(id) {
		return Pesanan{}, errTidakAda
	}
	l.Bersihkan(ctx)
	p, err := tanganiTidakAda(l.Store.Pesanan(ctx, id))
	if err != nil {
		return p, err
	}
	if p.IDAkun != a.ID && !(p.IDMitra == a.ID && p.DibayarPada != nil) {
		return Pesanan{}, errTidakAda
	}
	return p, nil
}

// ubahMilik ngubah pesanan yang dimiliki [a] sebagai [peran] ("pembeli" / "mitra")
func (l *Layanan) ubahMilik(ctx context.Context, a akun.Akun, id, peran string,
	ubah func(p *Pesanan) (Perubahan, error)) (Pesanan, error) {
	if !idSah(id) {
		return Pesanan{}, errTidakAda
	}
	return tanganiTidakAda(l.Store.UbahPesanan(ctx, id, func(p *Pesanan) (Perubahan, error) {
		milik := (peran == "pembeli" && p.IDAkun == a.ID) ||
			(peran == "mitra" && p.IDMitra == a.ID && p.DibayarPada != nil)
		if a.Peran != peran || !milik {
			return Perubahan{}, ErrTidakAda
		}
		// batas bayar udah lewat: batal otomatis dulu, baru aksi lain dicek
		if p.Status == MenungguBayar && !l.sekarang().Before(p.BatasBayar) {
			l.batal(p, "Batas waktu pembayaran habis.", true)
			return Perubahan{KembalikanStok: true}, nil
		}
		return ubah(p)
	}))
}

func (l *Layanan) batal(p *Pesanan, alasan string, otomatis bool) {
	now := l.sekarang()
	p.Status = Dibatalkan
	p.Alasan = &alasan
	p.Otomatis = otomatis
	p.DibatalkanPada = &now
}

// CekBayar "Saya sudah bayar · cek status". status lunas cuma ditentukan server (NF-10).
// pakai Midtrans: statusnya ditanya ke Midtrans. mode uji: langsung dianggap lunas
func (l *Layanan) CekBayar(ctx context.Context, a akun.Akun, id string) (Pesanan, error) {
	if l.Gerbang != nil {
		return l.cekBayarGerbang(ctx, a, id)
	}
	for range 5 {
		p, err := l.ubahMilik(ctx, a, id, "pembeli", func(p *Pesanan) (Perubahan, error) {
			if p.Status != MenungguBayar {
				// udah lunas / batal: jawab apa adanya, request ulang aman
				return Perubahan{}, nil
			}
			return l.lunasi(p)
		})
		if errors.Is(err, ErrBentrok) {
			continue // kode ambil kebetulan kembar sama pesanan aktif lain
		}
		return p, err
	}
	return Pesanan{}, errors.New("kode ambil bentrok terus")
}

// Batal F-55: pembeli cuma bisa batalin yang belum dibayar, porsinya balik (F-40)
func (l *Layanan) Batal(ctx context.Context, a akun.Akun, id, alasan string, otomatis bool) (Pesanan, error) {
	alasan = strings.TrimSpace(alasan)
	if alasan == "" {
		alasan = "Dibatalkan pembeli."
	}
	return l.ubahMilik(ctx, a, id, "pembeli", func(p *Pesanan) (Perubahan, error) {
		switch p.Status {
		case Dibatalkan:
			return Perubahan{}, nil
		case MenungguBayar:
			l.batal(p, alasan, otomatis)
			return Perubahan{KembalikanStok: true}, nil
		}
		return Perubahan{}, galat(http.StatusConflict, "Pesanan yang sudah dibayar tidak bisa dibatalkan.")
	})
}

// GantiMetode selama belum lunas, tagihan lama diganti yang baru
func (l *Layanan) GantiMetode(ctx context.Context, a akun.Akun, id, metode string) (Pesanan, error) {
	if !slices.Contains(metodeBayar, metode) {
		return Pesanan{}, galat(http.StatusUnprocessableEntity, "Pilih metode pembayaran.")
	}
	var lama string
	p, err := l.ubahMilik(ctx, a, id, "pembeli", func(p *Pesanan) (Perubahan, error) {
		if p.Status != MenungguBayar {
			return Perubahan{}, galat(http.StatusConflict, "Metode hanya bisa diganti sebelum dibayar.")
		}
		lama = p.Tagihan["idTagihan"]
		p.Metode = metode
		p.Tagihan = l.tagihan(p.ID, p.Total, metode)
		return Perubahan{}, nil
	})
	if err != nil || l.Gerbang == nil {
		return p, err
	}
	// tagihan lama dibatalin biar ga kebayar dua kali, lalu minta yang baru
	if lama != "" {
		_ = l.Gerbang.Batalkan(ctx, lama)
	}
	return l.pastikanTagihan(ctx, p)
}

// UbahStatus tahapan dari mitra: disiapkan -> siap diambil (F-43) -> selesai (F-20)
func (l *Layanan) UbahStatus(ctx context.Context, a akun.Akun, id, status string) (Pesanan, error) {
	return l.ubahMilik(ctx, a, id, "mitra", func(p *Pesanan) (Perubahan, error) {
		if p.Status == status {
			return Perubahan{}, nil
		}
		boleh := (status == SiapDiambil && p.Status == Disiapkan) ||
			(status == Selesai && (p.Status == Disiapkan || p.Status == SiapDiambil))
		if !boleh {
			return Perubahan{}, galat(http.StatusConflict, "Status pesanan tidak bisa diubah ke tahap itu.")
		}
		p.Status = status
		if status == Selesai {
			now := l.sekarang()
			p.DiambilPada = &now
		}
		return Perubahan{}, nil
	})
}

// BatalMitra F-42: pesanan lunas yang ga bisa dipenuhi. porsinya ga dibalikin,
// biasanya batal karena makanannya memang ga ada
func (l *Layanan) BatalMitra(ctx context.Context, a akun.Akun, id, alasan string) (Pesanan, error) {
	alasan = strings.TrimSpace(alasan)
	if alasan == "" {
		return Pesanan{}, galat(http.StatusUnprocessableEntity, "Tulis alasan pembatalan.")
	}
	return l.ubahMilik(ctx, a, id, "mitra", func(p *Pesanan) (Perubahan, error) {
		if p.Status == Dibatalkan {
			return Perubahan{}, nil
		}
		if p.Status != Disiapkan && p.Status != SiapDiambil {
			return Perubahan{}, galat(http.StatusConflict, "Pesanan ini tidak bisa dibatalkan.")
		}
		l.batal(p, alasan, false)
		p.OlehMitra = true
		return Perubahan{}, nil
	})
}

// AmbilDenganKode F-46: mitra scan / ketik kode ambil pembeli, pesanan langsung selesai
func (l *Layanan) AmbilDenganKode(ctx context.Context, a akun.Akun, kode string) (Pesanan, error) {
	if a.Peran != "mitra" {
		return Pesanan{}, errBukanMitra
	}
	kode = strings.ToUpper(strings.TrimSpace(kode))
	if !strings.HasPrefix(kode, "SR-") {
		kode = "SR-" + kode
	}
	semua, err := l.Store.PesananMitra(ctx, a.ID)
	if err != nil {
		return Pesanan{}, err
	}
	for _, p := range semua {
		if p.Kode == nil || *p.Kode != kode {
			continue
		}
		switch p.Status {
		case Selesai:
			return Pesanan{}, galat(http.StatusConflict, "Kode ini sudah dipakai. Pesanannya sudah diambil.")
		case Disiapkan, SiapDiambil:
			return l.UbahStatus(ctx, a, p.ID, Selesai)
		}
	}
	return Pesanan{}, galat(http.StatusNotFound, "Kode tidak ditemukan di pesanan gerai ini.")
}

// Bersihkan batalin pesanan yang batas bayarnya lewat dan balikin porsinya (F-40).
// dipanggil berkala dari main.go dan sebelum daftar pesanan dibaca
func (l *Layanan) Bersihkan(ctx context.Context) {
	id, err := l.Store.MenungguLewat(ctx, l.sekarang())
	if err != nil {
		return
	}
	for _, satu := range id {
		_, _ = l.Store.UbahPesanan(ctx, satu, func(p *Pesanan) (Perubahan, error) {
			if p.Status != MenungguBayar || l.sekarang().Before(p.BatasBayar) {
				return Perubahan{}, nil
			}
			l.batal(p, "Batas waktu pembayaran habis.", true)
			return Perubahan{KembalikanStok: true}, nil
		})
	}
}

// ---------- alat bantu ----------

// tagihan isi QR / nomor VA buat satu pesanan. pakai Midtrans: kosong dulu,
// diisi pastikanTagihan. mode uji: QRIS asli kalau QRISStatis diisi, sisanya tiruan
func (l *Layanan) tagihan(id string, total int, metode string) map[string]string {
	if l.Gerbang != nil {
		return map[string]string{}
	}
	t := tagihanUji(id, total)
	if metode == "qris" && l.QRISStatis != "" {
		if qr, err := QRISDinamis(l.QRISStatis, total); err == nil {
			t["isiQr"] = qr
			t["qrisAsli"] = "1"
		}
	}
	return t
}

// tagihanUji isi QR / nomor VA tiruan, sama kayak PembayaranTiruan di aplikasi.
// diganti tagihan Midtrans begitu pembayaran asli dipasang
func tagihanUji(id string, total int) map[string]string {
	angka := 0
	for _, c := range id {
		angka = (angka*31 + int(c)) % 100_000_000
	}
	nomor := fmt.Sprintf("80770812%08d", angka)
	return map[string]string{
		"isiQr":   fmt.Sprintf("SISARASA-UJI|%s|%d", id, total),
		"nomorVa": nomor[0:4] + " " + nomor[4:8] + " " + nomor[8:12] + " " + nomor[12:16],
	}
}

// acak [n] huruf dari [huruf] pakai crypto/rand, biar kode ambil ga bisa ditebak
func acak(huruf string, n int) (string, error) {
	b := make([]byte, n)
	for i := range b {
		k, err := rand.Int(rand.Reader, big.NewInt(int64(len(huruf))))
		if err != nil {
			return "", err
		}
		b[i] = huruf[k.Int64()]
	}
	return string(b), nil
}

// idBaru UUID v4 acak. dibuat di sini, bukan di database,
// karena tagihan butuh id pesanan sebelum barisnya disimpan
func idBaru() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16]), nil
}

// namaSingkat "Rani Amelia" jadi "Rani A.", sama kayak di aplikasi
func namaSingkat(nama string) string {
	kata := strings.Fields(nama)
	switch len(kata) {
	case 0:
		return ""
	case 1:
		return kata[0]
	}
	return kata[0] + " " + string([]rune(kata[1])[:1]) + "."
}

// MarshalJSON nambahin porsiPaket yang dipakai aplikasi buat ngitung stok
func (p Pesanan) MarshalJSON() ([]byte, error) {
	type polos Pesanan
	if p.Tagihan == nil {
		p.Tagihan = map[string]string{}
	}
	if p.Isi == nil {
		p.Isi = []IsiPesanan{}
	}
	return json.Marshal(struct {
		polos
		PorsiPaket map[string]int `json:"porsiPaket"`
	}{polos(p), p.PorsiPaket()})
}
