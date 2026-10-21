package toko

import (
	"context"
	"slices"
	"sort"
	"sync"
	"time"
)

// storeMemori pengganti Postgres di tes. satu mutex buat semuanya,
// jadi tiap operasi atomik kayak transaksi di StorePG
type storeMemori struct {
	mu      sync.Mutex
	nama    map[string]string // id akun mitra -> nama gerai
	gerai   map[string]Gerai
	tutup   map[string]bool
	paket   []Paket
	pesanan []Pesanan
	chat    []PesanChat
	rek     map[string]Rekening
	status  map[string]StatusGerai
	cair    map[string][]Pencairan
	favorit map[string][]string // id pembeli -> id mitra, terbaru di depan
	urut    int
}

func memoriBaru() *storeMemori {
	return &storeMemori{nama: map[string]string{}, gerai: map[string]Gerai{}, tutup: map[string]bool{},
		rek: map[string]Rekening{}, cair: map[string][]Pencairan{}, status: map[string]StatusGerai{},
		favorit: map[string][]string{}}
}

// tambahMitra mitra contoh di tes, langsung terverifikasi kayak mitra semaian
func (s *storeMemori) tambahMitra(id, nama string) {
	s.nama[id] = nama
	s.status[id] = StatusGerai{Status: GeraiTerverifikasi}
}

// tambahMitraBaru mitra yang baru daftar, belum diverifikasi admin
func (s *storeMemori) tambahMitraBaru(id, nama string) { s.nama[id] = nama }

func (s *storeMemori) statusDari(id string) StatusGerai {
	if st, ada := s.status[id]; ada {
		return st
	}
	return StatusGerai{Status: GeraiMenunggu}
}

func (s *storeMemori) lengkapi(p Paket) Paket {
	g := s.gerai[p.IDMitra]
	p.Mitra, p.JenisMitra, p.Alamat, p.Jarak = s.nama[p.IDMitra], g.Jenis, g.Alamat, g.Jarak
	if p.JenisMitra == "" {
		p.JenisMitra = "Mitra"
	}
	p.GeraiTutup = s.tutup[p.IDMitra]
	p.StatusGerai = s.statusDari(p.IDMitra).Status
	return p
}

func (s *storeMemori) SemuaPaket(_ context.Context, idMitra string) ([]Paket, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	hasil := []Paket{}
	for _, p := range s.paket {
		p = s.lengkapi(p)
		if !p.dihapus && (p.StatusGerai == GeraiTerverifikasi || p.IDMitra == idMitra) {
			hasil = append(hasil, p)
		}
	}
	return hasil, nil
}

func (s *storeMemori) PaketMitra(_ context.Context, idMitra string) ([]Paket, error) {
	semua, _ := s.SemuaPaket(context.Background(), idMitra)
	hasil := []Paket{}
	for _, p := range semua {
		if p.IDMitra == idMitra {
			hasil = append(hasil, p)
		}
	}
	return hasil, nil
}

func (s *storeMemori) SimpanGerai(_ context.Context, idMitra string, g Gerai) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.gerai[idMitra] = g
	return nil
}

func (s *storeMemori) AturGerai(_ context.Context, idMitra string, tutup bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.tutup[idMitra] = tutup
	return nil
}

func (s *storeMemori) BuatPaket(_ context.Context, idMitra string, isi IsianPaket) (Paket, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	id, _ := idBaru()
	p := Paket{ID: id, IDMitra: idMitra, Nama: isi.Nama, Deskripsi: isi.Deskripsi,
		Kategori: isi.Kategori, Foto: isi.Foto, Halal: isi.Halal, MejaBerbagi: isi.MejaBerbagi,
		HargaAsli: isi.HargaAsli, HargaDiskon: isi.HargaDiskon, TotalPorsi: isi.TotalPorsi,
		SisaPorsi: isi.TotalPorsi, Mulai: isi.Mulai, Tutup: isi.Tutup}
	s.paket = append(s.paket, p)
	return s.lengkapi(p), nil
}

func (s *storeMemori) ubahPaket(idMitra, id string, ubah func(p *Paket)) (Paket, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.paket {
		p := &s.paket[i]
		if p.ID == id && p.IDMitra == idMitra && !p.dihapus {
			ubah(p)
			return s.lengkapi(*p), nil
		}
	}
	return Paket{}, ErrTidakAda
}

func (s *storeMemori) UbahPaket(_ context.Context, idMitra, id string, isi IsianPaket) (Paket, error) {
	return s.ubahPaket(idMitra, id, func(p *Paket) {
		p.SisaPorsi = min(isi.TotalPorsi, max(0, p.SisaPorsi+isi.TotalPorsi-p.TotalPorsi))
		p.Nama, p.Deskripsi, p.Kategori, p.Foto = isi.Nama, isi.Deskripsi, isi.Kategori, isi.Foto
		p.Halal, p.MejaBerbagi, p.HargaAsli, p.HargaDiskon = isi.Halal, isi.MejaBerbagi, isi.HargaAsli, isi.HargaDiskon
		p.TotalPorsi, p.Mulai, p.Tutup = isi.TotalPorsi, isi.Mulai, isi.Tutup
	})
}

func (s *storeMemori) AturSisa(_ context.Context, idMitra, id string, sisa int) (Paket, error) {
	return s.ubahPaket(idMitra, id, func(p *Paket) { p.SisaPorsi = min(sisa, p.TotalPorsi) })
}

func (s *storeMemori) AturAktif(_ context.Context, idMitra, id string, aktif bool) (Paket, error) {
	return s.ubahPaket(idMitra, id, func(p *Paket) { p.Nonaktif = !aktif })
}

func (s *storeMemori) HapusPaket(_ context.Context, idMitra, id string) error {
	_, err := s.ubahPaket(idMitra, id, func(p *Paket) { p.dihapus = true })
	return err
}

func (s *storeMemori) BuatPesanan(_ context.Context, baru PesananBaru,
	susun func(paket []Paket) (Pesanan, error)) (Pesanan, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, p := range s.pesanan {
		if p.IDAkun == baru.IDPembeli && p.kunci == baru.Kunci {
			return p, false, nil
		}
	}
	var dikunci []Paket
	for _, p := range s.paket {
		if _, ada := baru.Isi[p.ID]; ada {
			dikunci = append(dikunci, s.lengkapi(p))
		}
	}
	sort.Slice(dikunci, func(i, j int) bool { return dikunci[i].ID < dikunci[j].ID })
	p, err := susun(dikunci)
	if err != nil {
		return Pesanan{}, false, err
	}
	for _, lama := range s.pesanan {
		if lama.Nomor == p.Nomor {
			return Pesanan{}, false, ErrBentrok
		}
	}
	for i := range s.paket {
		s.paket[i].SisaPorsi -= baru.Isi[s.paket[i].ID]
	}
	s.urut++
	p.Dibuat = p.Dibuat.Add(time.Duration(s.urut)) // urutan terbaru tetap jelas walau jam dikunci
	s.pesanan = append(s.pesanan, p)
	return p, true, nil
}

func (s *storeMemori) Pesanan(_ context.Context, id string) (Pesanan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, p := range s.pesanan {
		if p.ID == id {
			return p, nil
		}
	}
	return Pesanan{}, ErrTidakAda
}

func (s *storeMemori) saring(cocok func(Pesanan) bool) []Pesanan {
	s.mu.Lock()
	defer s.mu.Unlock()
	hasil := []Pesanan{}
	for _, p := range s.pesanan {
		if cocok(p) {
			hasil = append(hasil, p)
		}
	}
	sort.Slice(hasil, func(i, j int) bool { return hasil[i].Dibuat.After(hasil[j].Dibuat) })
	return hasil
}

func (s *storeMemori) PesananPembeli(_ context.Context, id string) ([]Pesanan, error) {
	return s.saring(func(p Pesanan) bool { return p.IDAkun == id }), nil
}

func (s *storeMemori) PesananMitra(_ context.Context, id string) ([]Pesanan, error) {
	return s.saring(func(p Pesanan) bool { return p.IDMitra == id }), nil
}

func (s *storeMemori) UbahPesanan(_ context.Context, id string,
	ubah func(p *Pesanan) (Perubahan, error)) (Pesanan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.pesanan {
		if s.pesanan[i].ID != id {
			continue
		}
		salinan := s.pesanan[i]
		salinan.Isi = append([]IsiPesanan(nil), salinan.Isi...)
		per, err := ubah(&salinan)
		if err != nil {
			return Pesanan{}, err
		}
		// indeks unik kode ambil aktif, sama kayak pesanan_kode_aktif
		if salinan.Kode != nil && (salinan.Status == Disiapkan || salinan.Status == SiapDiambil) {
			for j, lain := range s.pesanan {
				if j != i && lain.Kode != nil && *lain.Kode == *salinan.Kode &&
					(lain.Status == Disiapkan || lain.Status == SiapDiambil) {
					return Pesanan{}, ErrBentrok
				}
			}
		}
		if per.KembalikanStok {
			for _, isi := range salinan.Isi {
				for k := range s.paket {
					if s.paket[k].ID == isi.IDPaket {
						s.paket[k].SisaPorsi = min(s.paket[k].TotalPorsi, s.paket[k].SisaPorsi+isi.Jumlah)
					}
				}
			}
		}
		s.pesanan[i] = salinan
		return salinan, nil
	}
	return Pesanan{}, ErrTidakAda
}

func (s *storeMemori) MenungguLewat(_ context.Context, sekarang time.Time) ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var id []string
	for _, p := range s.pesanan {
		if p.Status == MenungguBayar && !p.BatasBayar.After(sekarang) {
			id = append(id, p.ID)
		}
	}
	return id, nil
}

func (s *storeMemori) SimpanPesan(_ context.Context, p PesanChat) (PesanChat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, lama := range s.chat {
		if lama.IDPesanan == p.IDPesanan && lama.ID == p.ID {
			return lama, nil
		}
	}
	s.chat = append(s.chat, p)
	return p, nil
}

func (s *storeMemori) DaftarPesan(_ context.Context, idPesanan string) ([]PesanChat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	hasil := []PesanChat{}
	for _, p := range s.chat {
		if p.IDPesanan == idPesanan {
			hasil = append(hasil, p)
		}
	}
	return hasil, nil
}

func (s *storeMemori) TandaiDibaca(_ context.Context, idPesanan, oleh string, sekarang time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.chat {
		p := &s.chat[i]
		if p.IDPesanan == idPesanan && p.Peran != oleh && p.DibacaPada == nil {
			t := sekarang
			p.DibacaPada, p.Diubah = &t, sekarang
		}
	}
	return nil
}

func (s *storeMemori) PesanBaru(_ context.Context, idAkun, peran string, setelah time.Time) ([]PesanChat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	milik := map[string]bool{}
	for _, p := range s.pesanan {
		if (peran == "pembeli" && p.IDAkun == idAkun) || (peran == "mitra" && p.IDMitra == idAkun && p.DibayarPada != nil) {
			milik[p.ID] = true
		}
	}
	hasil := []PesanChat{}
	for _, c := range s.chat {
		if milik[c.IDPesanan] && c.Diubah.After(setelah) {
			hasil = append(hasil, c)
		}
	}
	return hasil, nil
}

func (s *storeMemori) Rekening(_ context.Context, id string) (*Rekening, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if r, ada := s.rek[id]; ada {
		return &r, nil
	}
	return nil, nil
}

func (s *storeMemori) SimpanRekening(_ context.Context, id string, r Rekening, _ time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rek[id] = r
	return nil
}

func (s *storeMemori) DaftarPencairan(_ context.Context, id string) ([]Pencairan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]Pencairan{}, s.cair[id]...), nil
}

func (s *storeMemori) pendapatan(id string) []int {
	var hasil []int
	for _, p := range s.pesanan {
		if p.IDMitra == id && (p.Status == Selesai || p.Status == TidakDiambil) {
			hasil = append(hasil, p.Subtotal)
		}
	}
	return hasil
}

func (s *storeMemori) Pendapatan(_ context.Context, id string) ([]int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.pendapatan(id), nil
}

func (s *storeMemori) MitraBerekening(context.Context) ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var id []string
	for k := range s.rek {
		id = append(id, k)
	}
	return id, nil
}

func (s *storeMemori) Cairkan(_ context.Context, id, kunci string,
	hitung func(pendapatan []int, lama []Pencairan, r *Rekening) *Pencairan) (*Pencairan, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.cair[id] {
		if c.kunci == kunci {
			return nil, nil
		}
	}
	var r *Rekening
	if rek, ada := s.rek[id]; ada {
		r = &rek
	}
	p := hitung(s.pendapatan(id), s.cair[id], r)
	if p == nil {
		return nil, nil
	}
	p.ID, _ = idBaru()
	p.kunci = kunci
	s.cair[id] = append([]Pencairan{*p}, s.cair[id]...)
	return p, nil
}

func (s *storeMemori) StatusGerai(_ context.Context, id string) (StatusGerai, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ada := s.nama[id]; !ada {
		return StatusGerai{}, ErrTidakAda
	}
	return s.statusDari(id), nil
}

func (s *storeMemori) DaftarMitra(_ context.Context, status string) ([]MitraAdmin, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	hasil := []MitraAdmin{}
	for id, nama := range s.nama {
		st := s.statusDari(id)
		if status != "" && st.Status != status {
			continue
		}
		hasil = append(hasil, MitraAdmin{ID: id, Nama: nama, Status: st.Status, Alasan: st.Alasan})
	}
	return hasil, nil
}

func (s *storeMemori) PeriksaMitra(_ context.Context, id, status string, alasan *string, _ time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ada := s.nama[id]; !ada {
		return ErrTidakAda
	}
	s.status[id] = StatusGerai{Status: status, Alasan: alasan}
	return nil
}

func (s *storeMemori) Favorit(_ context.Context, idPembeli string) ([]MitraFavorit, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	hasil := []MitraFavorit{}
	for _, id := range s.favorit[idPembeli] {
		jenis := s.gerai[id].Jenis
		if jenis == "" {
			jenis = "Mitra"
		}
		hasil = append(hasil, MitraFavorit{ID: id, Nama: s.nama[id], Jenis: jenis})
	}
	return hasil, nil
}

func (s *storeMemori) AturFavorit(_ context.Context, idPembeli, idMitra string, suka bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	daftar := slices.DeleteFunc(s.favorit[idPembeli], func(id string) bool { return id == idMitra })
	if suka {
		if _, ada := s.nama[idMitra]; !ada {
			return ErrTidakAda
		}
		daftar = append([]string{idMitra}, daftar...)
	}
	s.favorit[idPembeli] = daftar
	return nil
}

var _ Store = (*storeMemori)(nil)
