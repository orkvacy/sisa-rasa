package toko

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
	"github.com/orkvacy/sisa-rasa/backend/internal/httpx"
)

// gerai + paket contoh, sama kayak data_deals.dart di aplikasi.
// cuma disemai di dev / server demo (SEMAI_AKUN_CONTOH=1)
type geraiContoh struct {
	nama, email string
	gerai       Gerai
	paket       []paketContoh
}

type paketContoh struct {
	IsianPaket
	sisa int
}

func jam(j, m int) int { return j*60 + m }

var contoh = []geraiContoh{
	{"Ibis Hotel", "dapur.ibis@contoh.id", Gerai{"Hotel", "Jl. Mulawarman 2, Samarinda", "1,9 km"}, []paketContoh{
		{IsianPaket{Nama: "American Breakfast Set", Kategori: "Hidangan utama", Halal: true,
			Deskripsi: "Dua telur mata sapi, sosis sapi, beef bacon, hash brown, dan roti panggang dari buffet sarapan hotel.",
			Foto:      "assets/images/paket/american_breakfast.jpg", HargaAsli: 85000, HargaDiskon: 34000,
			TotalPorsi: 8, Mulai: jam(15, 0), Tutup: jam(17, 0)}, 3},
		{IsianPaket{Nama: "Petit Four & Macaron", Kategori: "Dessert", Halal: true,
			Deskripsi: "Dua macaron, satu mousse stroberi, dan dua kue kecil dari sesi coffee break rapat.",
			Foto:      "assets/images/paket/petit_four.jpg", HargaAsli: 95000, HargaDiskon: 38000,
			TotalPorsi: 6, Mulai: jam(15, 0), Tutup: jam(17, 0)}, 4},
	}},
	{"Prime Cut Steakhouse", "dapur.primecut@contoh.id", Gerai{"Restoran", "Jl. Juanda 12, Samarinda", "1,5 km"}, []paketContoh{
		{IsianPaket{Nama: "Sirloin Steak Black Pepper", Kategori: "Hidangan utama",
			Deskripsi: "Sirloin 200 g dimasak medium, kentang panggang, jamur tumis, dan saus lada hitam. Sisa persiapan makan siang.",
			Foto:      "assets/images/paket/sirloin.jpg", HargaAsli: 245000, HargaDiskon: 62000,
			TotalPorsi: 4, Mulai: jam(15, 0), Tutup: jam(17, 0)}, 3},
	}},
	{"Teras Nusantara", "dapur.teras@contoh.id", Gerai{"Restoran", "Jl. Pramuka 21, Samarinda", "0,8 km"}, []paketContoh{
		{IsianPaket{Nama: "Iga Bakar Madu", Kategori: "Hidangan utama", Halal: true,
			Deskripsi: "Iga sapi bakar bumbu madu, nasi putih, lalapan, dan sambal matah. Dimasak siang ini.",
			Foto:      "assets/images/paket/iga_bakar.jpg", HargaAsli: 125000, HargaDiskon: 50000,
			TotalPorsi: 6, Mulai: jam(16, 30), Tutup: jam(18, 0)}, 2},
	}},
	{"Bumi Senyiur", "dapur.bumisenyiur@contoh.id", Gerai{"Hotel", "Jl. Pangeran Diponegoro 17, Samarinda", "1,2 km"}, []paketContoh{
		{IsianPaket{Nama: "Paket Buffet Makan Malam", Kategori: "Buffet hotel", Halal: true,
			Deskripsi: "Sisa buffet: smoked salmon, dua hidangan utama, salad, dan dessert. Isinya berganti tiap hari dan ditentukan dapur, jadi tidak bisa dipilih.",
			Foto:      "assets/images/paket/buffet_hotel.jpg", HargaAsli: 250000, HargaDiskon: 95000,
			TotalPorsi: 10, Mulai: jam(17, 0), Tutup: jam(19, 0)}, 4},
	}},
	{"Kaze Japanese Dining", "dapur.kaze@contoh.id", Gerai{"Restoran", "Jl. Juanda 8, Samarinda", "2,5 km"}, []paketContoh{
		{IsianPaket{Nama: "Salmon Teriyaki Set", Kategori: "Hidangan utama",
			Deskripsi: "Salmon panggang saus teriyaki, nasi Jepang, sup miso, salad, dan buah. Sisa set makan siang.",
			Foto:      "assets/images/paket/salmon_teriyaki.jpg", HargaAsli: 145000, HargaDiskon: 58000,
			TotalPorsi: 12, Mulai: jam(18, 0), Tutup: jam(20, 0)}, 8},
	}},
	{"Maison Roti", "dapur.maison@contoh.id", Gerai{"Bakery", "Jl. Awang Long 5, Samarinda", "3,1 km"}, []paketContoh{
		{IsianPaket{Nama: "Sourdough Country Loaf", Kategori: "Pastry & roti",
			Deskripsi: "Satu loaf sourdough fermentasi 24 jam, dipanggang pagi ini. Tahan sampai dua hari di suhu ruang.",
			Foto:      "assets/images/paket/sourdough.jpg", HargaAsli: 90000, HargaDiskon: 36000,
			TotalPorsi: 6, Mulai: jam(19, 0), Tutup: jam(21, 0)}, 5},
	}},
	{"Swiss-Belhotel", "dapur.swissbel@contoh.id", Gerai{"Hotel", "Jl. Mulawarman 6, Samarinda", "2,2 km"}, []paketContoh{
		{IsianPaket{Nama: "Sushi Platter Nigiri", Kategori: "Hidangan utama",
			Deskripsi: "Delapan nigiri dan satu gulung maki dari restoran Jepang hotel. Disimpan dingin, sebaiknya dimakan malam ini.",
			Foto:      "assets/images/paket/sushi.jpg", HargaAsli: 220000, HargaDiskon: 88000,
			TotalPorsi: 8, Mulai: jam(19, 0), Tutup: jam(21, 0)}, 4},
	}},
}

// SemaiContoh bikin akun mitra contoh + gerai + paketnya. paket cuma dibuat
// kalau mitra itu belum punya paket sama sekali, jadi aman dijalanin tiap server nyala
func SemaiContoh(ctx context.Context, l *Layanan, ak *akun.Layanan) error {
	for _, g := range contoh {
		_, err := ak.Daftar(ctx, g.nama, g.email, akun.SandiContoh, "mitra")
		var gl *httpx.Galat
		if err != nil && !(errors.As(err, &gl) && gl.Kode == http.StatusConflict) {
			return err
		}
		a, err := ak.Cari(ctx, g.email)
		if err != nil {
			return err
		}
		if err := l.Store.SimpanGerai(ctx, a.ID, g.gerai); err != nil {
			return err
		}
		// rekening contoh, sama kayak SaldoLokal di aplikasi
		if rek, err := l.Store.Rekening(ctx, a.ID); err != nil {
			return err
		} else if rek == nil {
			if err := l.Store.SimpanRekening(ctx, a.ID, Rekening{Bank: "BCA", Nomor: "1234567890",
				Nama: strings.ToUpper(g.nama)}, l.sekarang()); err != nil {
				return err
			}
		}
		ada, err := l.Store.PaketMitra(ctx, a.ID)
		if err != nil {
			return err
		}
		if len(ada) > 0 {
			continue
		}
		for _, p := range g.paket {
			baru, err := l.BuatPaket(ctx, a, p.IsianPaket)
			if err != nil {
				return err
			}
			if _, err := l.Store.AturSisa(ctx, a.ID, baru.ID, p.sisa); err != nil {
				return err
			}
		}
	}
	return nil
}
