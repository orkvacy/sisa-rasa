package toko

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/akun"
)

func ujiVoucher(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()
	kini := x.jam.sekarang()
	isian := func(kode string) IsianVoucher {
		return IsianVoucher{Kode: kode, Judul: "Hemat sore", Persen: 20, MaksPotongan: 10000,
			MinBelanja: 30000, Mulai: kini.Add(-time.Hour), Berakhir: kini.Add(24 * time.Hour), Publik: true}
	}

	// ---- admin bikin voucher ----
	if _, err := x.l.BuatVoucher(ctx, rani, isian("HEMAT20")); kodeGalat(err) != http.StatusForbidden {
		t.Fatalf("pembeli bikin voucher: %v", err)
	}
	salah := isian("ab")
	if _, err := x.l.BuatVoucher(ctx, admin, salah); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("kode kependekan: %v", err)
	}
	salah = isian("MUNDUR")
	salah.Berakhir = salah.Mulai
	if _, err := x.l.BuatVoucher(ctx, admin, salah); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("tanggal mundur: %v", err)
	}
	hemat, err := x.l.BuatVoucher(ctx, admin, isian(" hemat 20 "))
	if err != nil || hemat.Kode != "HEMAT20" || !hemat.Aktif {
		t.Fatalf("voucher hemat: %+v %v", hemat, err)
	}
	if _, err := x.l.BuatVoucher(ctx, admin, isian("HEMAT20")); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("kode kembar: %v", err)
	}
	satu := 1
	baru := isian("PERTAMA")
	baru.Persen, baru.MaksPotongan, baru.MinBelanja, baru.KhususBaru, baru.Kuota = 50, 15000, 0, true, &satu
	if _, err := x.l.BuatVoucher(ctx, admin, baru); err != nil {
		t.Fatal(err)
	}
	rahasia := isian("RAHASIA")
	rahasia.Publik = false
	if _, err := x.l.BuatVoucher(ctx, admin, rahasia); err != nil {
		t.Fatal(err)
	}
	nanti := isian("NANTI")
	nanti.Mulai, nanti.Berakhir = kini.Add(time.Hour), kini.Add(2*time.Hour)
	if _, err := x.l.BuatVoucher(ctx, admin, nanti); err != nil {
		t.Fatal(err)
	}

	// ---- daftar voucher pembeli: yang publik, lagi berlaku, dan boleh dipakai ----
	kode := func(daftar []Voucher) map[string]bool {
		m := map[string]bool{}
		for _, v := range daftar {
			m[v.Kode] = true
		}
		return m
	}
	tersedia, err := x.l.VoucherTersedia(ctx, rani)
	if err != nil {
		t.Fatal(err)
	}
	if k := kode(tersedia); !k["HEMAT20"] || !k["PERTAMA"] || k["RAHASIA"] || k["NANTI"] {
		t.Fatalf("daftar voucher: %v", k)
	}

	// ---- cek di checkout ----
	if _, err := x.l.CekVoucher(ctx, rani, "HEMAT20", 20000); kodeGalat(err) != http.StatusUnprocessableEntity {
		t.Fatalf("kurang dari minimal belanja: %v", err)
	}
	if h, err := x.l.CekVoucher(ctx, rani, "hemat20", 38000); err != nil || h.Potongan != 7600 {
		t.Fatalf("20%% dari 38rb: %+v %v", h, err)
	}
	if h, _ := x.l.CekVoucher(ctx, rani, "HEMAT20", 76000); h.Potongan != 10000 {
		t.Fatalf("maksimal potongan: %d", h.Potongan)
	}
	if _, err := x.l.CekVoucher(ctx, rani, "NANTI", 50000); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("belum berlaku: %v", err)
	}
	if _, err := x.l.CekVoucher(ctx, rani, "NGAWUR", 50000); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("kode ngawur: %v", err)
	}
	if _, err := x.l.CekVoucher(ctx, rani, "RAHASIA", 50000); err != nil {
		t.Fatalf("kode rahasia tetap bisa diketik: %v", err)
	}

	// ---- pesanan pertama rani pakai PERTAMA (khusus pengguna baru, kuota 1) ----
	p, dibuat, err := x.l.BuatPesananVoucher(ctx, rani, map[string]int{x.kue.ID: 1}, "qris", "kunci-voucher-1", "pertama")
	if err != nil || !dibuat {
		t.Fatalf("pesanan voucher: %v", err)
	}
	// kue 38rb: potongan 50% = 19rb, maks 15rb. potongan ga ngubah subtotal (bagian mitra)
	if p.Subtotal != 38000 || p.Potongan != 15000 || p.Total != 38000+3800-15000 ||
		p.KodeVoucher == nil || *p.KodeVoucher != "PERTAMA" {
		t.Fatalf("hitungan voucher: subtotal %d potongan %d total %d", p.Subtotal, p.Potongan, p.Total)
	}
	// request diulang (kunci sama): pesanan yang sama, walau voucher-nya sekarang udah "kepakai"
	ulang, dibuat, err := x.l.BuatPesananVoucher(ctx, rani, map[string]int{x.kue.ID: 1}, "qris", "kunci-voucher-1", "PERTAMA")
	if err != nil || dibuat || ulang.ID != p.ID {
		t.Fatalf("request diulang: %v dibuat=%v", err, dibuat)
	}
	// rani udah pernah pesan: PERTAMA ga bisa lagi, dan ilang dari daftarnya
	if _, _, err := x.l.BuatPesananVoucher(ctx, rani, map[string]int{x.kue.ID: 1}, "qris", "kunci-voucher-2", "PERTAMA"); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("khusus pesanan pertama: %v", err)
	}
	if k := kode(mustTersedia(t, x.l, ctx, rani)); k["PERTAMA"] {
		t.Fatal("PERTAMA harus ilang dari daftar rani")
	}
	// dimas pengguna baru juga, tapi kuotanya (1) udah dipakai rani
	if _, _, err := x.l.BuatPesananVoucher(ctx, dimas, map[string]int{x.kue.ID: 1}, "qris", "kunci-voucher-3", "PERTAMA"); err != errVoucherHabis {
		t.Fatalf("kuota habis: %v", err)
	}
	// rani batal sebelum bayar: kuota balik, dimas bisa pakai
	if _, err := x.l.Batal(ctx, rani, p.ID, "", false); err != nil {
		t.Fatal(err)
	}
	if q, _, err := x.l.BuatPesananVoucher(ctx, dimas, map[string]int{x.kue.ID: 1}, "qris", "kunci-voucher-4", "PERTAMA"); err != nil || q.Potongan != 15000 {
		t.Fatalf("kuota balik abis batal: %v", err)
	}

	// ---- voucher dimatiin admin ----
	if _, err := x.l.AturVoucherAktif(ctx, admin, hemat.ID, false); err != nil {
		t.Fatal(err)
	}
	if _, err := x.l.CekVoucher(ctx, rani, "HEMAT20", 50000); kodeGalat(err) != http.StatusNotFound {
		t.Fatalf("voucher nonaktif: %v", err)
	}
	semua, err := x.l.DaftarVoucher(ctx, admin)
	if err != nil || len(semua) != 4 {
		t.Fatalf("daftar admin: %d %v", len(semua), err)
	}
	// kadaluwarsa
	x.jam.maju(25 * time.Hour)
	if _, err := x.l.CekVoucher(ctx, rani, "RAHASIA", 50000); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("voucher berakhir: %v", err)
	}
}

func mustTersedia(t *testing.T, l *Layanan, ctx context.Context, a akun.Akun) []Voucher {
	t.Helper()
	d, err := l.VoucherTersedia(ctx, a)
	if err != nil {
		t.Fatal(err)
	}
	return d
}
