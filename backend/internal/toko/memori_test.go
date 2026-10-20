package toko

import (
	"context"
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
	urut    int
}

func memoriBaru() *storeMemori {
	return &storeMemori{nama: map[string]string{}, gerai: map[string]Gerai{}, tutup: map[string]bool{}}
}

func (s *storeMemori) tambahMitra(id, nama string) { s.nama[id] = nama }

func (s *storeMemori) lengkapi(p Paket) Paket {
	g := s.gerai[p.IDMitra]
	p.Mitra, p.JenisMitra, p.Alamat, p.Jarak = s.nama[p.IDMitra], g.Jenis, g.Alamat, g.Jarak
	if p.JenisMitra == "" {
		p.JenisMitra = "Mitra"
	}
	p.GeraiTutup = s.tutup[p.IDMitra]
	return p
}

func (s *storeMemori) SemuaPaket(context.Context) ([]Paket, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	hasil := []Paket{}
	for _, p := range s.paket {
		if !p.dihapus {
			hasil = append(hasil, s.lengkapi(p))
		}
	}
	return hasil, nil
}

func (s *storeMemori) PaketMitra(_ context.Context, idMitra string) ([]Paket, error) {
	semua, _ := s.SemuaPaket(context.Background())
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

var _ Store = (*storeMemori)(nil)
