// Package toko ngurus gerai mitra, paket yang dijual, dan pesanan pembeli.
// nama field JSON-nya sengaja sama kayak Map di aplikasi, biar layar ga perlu diubah
package toko

import (
	"context"
	"errors"
	"time"
)

// status pesanan, sama persis sama StatusPesanan di aplikasi (F-41)
const (
	MenungguBayar = "menunggu_bayar"
	Disiapkan     = "disiapkan"
	SiapDiambil   = "siap_diambil"
	Selesai       = "selesai"
	Dibatalkan    = "dibatalkan"
	TidakDiambil  = "tidak_diambil"
)

// Paket yang dikirim ke aplikasi, sudah digabung sama data gerainya
type Paket struct {
	ID         string `json:"id"`
	IDMitra    string `json:"idMitra"`
	Mitra      string `json:"mitra"`
	JenisMitra string `json:"jenisMitra"`
	Alamat     string `json:"alamat"`
	Jarak      string `json:"jarak"`
	GeraiTutup bool   `json:"geraiTutup"`
	// titik gerai. jarak ke pembeli dihitung di HP, lokasi pembeli ga dikirim ke server.
	// null kalau mitranya belum masang titik
	Lat *float64 `json:"lat"`
	Lng *float64 `json:"lng"`
	// StatusGerai verifikasi mitra (F-37). pembeli cuma liat yang terverifikasi
	StatusGerai string `json:"statusGerai"`
	Nama        string `json:"nama"`
	Deskripsi   string `json:"deskripsi"`
	Kategori    string `json:"kategori"`
	Foto        string `json:"foto"`
	Halal       bool   `json:"halal"`
	MejaBerbagi bool   `json:"mejaBerbagi"`
	HargaAsli   int    `json:"hargaAsli"`
	HargaDiskon int    `json:"hargaDiskon"`
	TotalPorsi  int    `json:"totalPorsi"`
	SisaPorsi   int    `json:"sisaPorsi"`
	Mulai       int    `json:"mulai"`
	Tutup       int    `json:"tutup"`
	Nonaktif    bool   `json:"nonaktif"`
	dihapus     bool
}

// IsianPaket yang diisi mitra di form paket (F-15, F-18)
type IsianPaket struct {
	Nama        string `json:"nama"`
	Deskripsi   string `json:"deskripsi"`
	Kategori    string `json:"kategori"`
	Foto        string `json:"foto"`
	Halal       bool   `json:"halal"`
	MejaBerbagi bool   `json:"mejaBerbagi"`
	HargaAsli   int    `json:"hargaAsli"`
	HargaDiskon int    `json:"hargaDiskon"`
	TotalPorsi  int    `json:"totalPorsi"`
	Mulai       int    `json:"mulai"`
	Tutup       int    `json:"tutup"`
}

// Gerai data toko mitra yang ditempel ke tiap paketnya
type Gerai struct {
	Jenis  string
	Alamat string
	Jarak  string
	// Titik koordinat gerai, nil = belum dipasang
	Titik *Titik
}

// Titik koordinat lintang / bujur (WGS84, sama kayak GPS di HP)
type Titik struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// IsiPesanan satu paket di dalam pesanan, disalin pas dipesan
type IsiPesanan struct {
	IDPaket   string `json:"idPaket"`
	Nama      string `json:"nama"`
	Deskripsi string `json:"deskripsi"`
	Foto      string `json:"foto"`
	Harga     int    `json:"harga"`
	HargaAsli int    `json:"hargaAsli"`
	Jumlah    int    `json:"jumlah"`
}

// Pesanan lengkap. Kode cuma diisi setelah lunas
type Pesanan struct {
	ID             string            `json:"id"`
	Nomor          string            `json:"nomor"`
	IDAkun         string            `json:"idAkun"`
	IDMitra        string            `json:"idMitra"`
	NamaPembeli    string            `json:"namaPembeli"`
	Mitra          string            `json:"mitra"`
	Alamat         string            `json:"alamat"`
	Foto           string            `json:"foto"`
	Mulai          int               `json:"mulai"`
	Tutup          int               `json:"tutup"`
	Status         string            `json:"status"`
	Metode         string            `json:"metode"`
	Kode           *string           `json:"kode"`
	Isi            []IsiPesanan      `json:"isi"`
	Porsi          int               `json:"porsi"`
	Subtotal       int               `json:"subtotal"`
	HargaNormal    int               `json:"hargaNormal"`
	BiayaLayanan   int               `json:"biayaLayanan"`
	Total          int               `json:"total"`
	Hemat          int               `json:"hemat"`
	Dipesan        int               `json:"dipesan"`
	Dibuat         time.Time         `json:"dibuat"`
	BatasBayar     time.Time         `json:"batasBayar"`
	BatasMenit     int               `json:"batasMenit"`
	DibayarPada    *time.Time        `json:"dibayarPada"`
	Dibayar        *int              `json:"dibayar"`
	DiambilPada    *time.Time        `json:"diambilPada"`
	DibatalkanPada *time.Time        `json:"dibatalkanPada"`
	Alasan         *string           `json:"alasan"`
	Otomatis       bool              `json:"otomatis"`
	OlehMitra      bool              `json:"olehMitra"`
	Tagihan        map[string]string `json:"tagihan"`
	kunci          string
	sidik          string
}

// PorsiPaket id paket -> jumlah, dipakai aplikasi buat ngitung stok
func (p Pesanan) PorsiPaket() map[string]int {
	hasil := make(map[string]int, len(p.Isi))
	for _, isi := range p.Isi {
		hasil[isi.IDPaket] = isi.Jumlah
	}
	return hasil
}

// PesananBaru permintaan pembeli yang belum dicek stoknya
type PesananBaru struct {
	IDPembeli   string
	NamaPembeli string
	Isi         map[string]int
	Metode      string
	Kunci       string
	Sidik       string
}

var (
	// ErrTidakAda baris yang dicari ga ada (atau bukan milik akun itu)
	ErrTidakAda = errors.New("tidak ada")
	// ErrBentrok nomor / kode acak kebetulan udah dipakai, tinggal diulang
	ErrBentrok = errors.New("bentrok")
)

// Perubahan hasil fungsi ubah di Store.UbahPesanan
type Perubahan struct {
	// porsi pesanan dibalikin ke stok paket (F-40)
	KembalikanStok bool
}

// Store tempat nyimpen gerai, paket, dan pesanan. versi aslinya Postgres (store_pg.go),
// di tes pakai versi memori. operasi yang nyentuh stok harus atomik
type Store interface {
	// SemuaPaket paket dari gerai terverifikasi, plus paket milik [idMitra]
	// (mitra yang lagi masuk tetap liat paketnya sendiri walau belum diverifikasi)
	SemuaPaket(ctx context.Context, idMitra string) ([]Paket, error)
	PaketMitra(ctx context.Context, idMitra string) ([]Paket, error)
	SimpanGerai(ctx context.Context, idMitra string, g Gerai) error
	// AturLokasi titik gerai dari GPS HP mitra
	AturLokasi(ctx context.Context, idMitra string, t Titik) error
	AturGerai(ctx context.Context, idMitra string, tutup bool) error
	BuatPaket(ctx context.Context, idMitra string, isi IsianPaket) (Paket, error)
	// UbahPaket: kalau total porsi diganti, sisa ikut geser sebanyak selisihnya
	UbahPaket(ctx context.Context, idMitra, id string, isi IsianPaket) (Paket, error)
	AturSisa(ctx context.Context, idMitra, id string, sisa int) (Paket, error)
	AturAktif(ctx context.Context, idMitra, id string, aktif bool) (Paket, error)
	HapusPaket(ctx context.Context, idMitra, id string) error

	// BuatPesanan ngunci paket yang dipesan, manggil [susun] buat ngecek + ngitung,
	// lalu ngurangin stok dan nyimpen pesanan, semuanya dalam satu transaksi.
	// kalau kunci idempotensi pembeli udah pernah dipakai, pesanan lama yang dibalikin
	// (baru = false) tanpa nyentuh stok
	BuatPesanan(ctx context.Context, baru PesananBaru,
		susun func(paket []Paket) (Pesanan, error)) (p Pesanan, dibuat bool, err error)
	Pesanan(ctx context.Context, id string) (Pesanan, error)
	PesananPembeli(ctx context.Context, idPembeli string) ([]Pesanan, error)
	PesananMitra(ctx context.Context, idMitra string) ([]Pesanan, error)
	// UbahPesanan ngunci satu pesanan, manggil [ubah], lalu nyimpen hasilnya
	UbahPesanan(ctx context.Context, id string,
		ubah func(p *Pesanan) (Perubahan, error)) (Pesanan, error)
	// MenungguLewat id pesanan yang masih nunggu bayar tapi batasnya udah lewat
	MenungguLewat(ctx context.Context, sekarang time.Time) ([]string, error)
	// BelumDiambil id pesanan lunas yang belum diambil (disiapkan / siap diambil).
	// lewat jam tutup ambil atau belum, dicek di Layanan
	BelumDiambil(ctx context.Context) ([]string, error)

	StoreChat
	StoreSaldo
	StoreVerifikasi
	StoreFavorit
}
