package toko

import (
	"context"
	"net/http"
	"testing"
	"time"
)

func ujiTidakDiambil(t *testing.T, siapkan func(*testing.T) siap) {
	x := siapkan(t)
	ctx := context.Background()

	// dua pesanan lunas dari paket yang tutup 17.00, jam sekarang 16.20
	bayar := func(kunci string) Pesanan {
		t.Helper()
		p, _, err := x.l.BuatPesanan(ctx, rani, map[string]int{x.kue.ID: 1}, "qris", kunci)
		if err != nil {
			t.Fatal(err)
		}
		if p, err = x.l.CekBayar(ctx, rani, p.ID); err != nil || p.Status != Disiapkan {
			t.Fatalf("bayar: %v %s", err, p.Status)
		}
		return p
	}
	p1 := bayar("kunci-tidak-ambil-1")
	p2 := bayar("kunci-tidak-ambil-2")
	saldoAwal, _ := x.l.SaldoSaya(ctx, ibis)

	// belum lewat jam tutup: ga diapa-apain
	x.l.Bersihkan(ctx)
	if q, _ := x.l.Satu(ctx, rani, p1.ID); q.Status != Disiapkan {
		t.Fatalf("sebelum jam tutup: %s", q.Status)
	}
	// satu diambil tepat waktu
	if _, err := x.l.AmbilDenganKode(ctx, ibis, *p2.Kode); err != nil {
		t.Fatal(err)
	}

	// lewat 17.00: yang belum diambil jadi Tidak diambil
	x.jam.maju(41 * time.Minute)
	x.l.Bersihkan(ctx)
	if q, _ := x.l.Satu(ctx, rani, p1.ID); q.Status != TidakDiambil {
		t.Fatalf("lewat jam tutup harus tidak diambil: %s", q.Status)
	}
	if q, _ := x.l.Satu(ctx, rani, p2.ID); q.Status != Selesai {
		t.Fatalf("yang udah diambil tetap selesai: %s", q.Status)
	}
	// penerimaan bersihnya tetap masuk saldo mitra (F-48)
	if s, _ := x.l.SaldoSaya(ctx, ibis); s.Tersedia <= saldoAwal.Tersedia {
		t.Fatalf("saldo mitra harus nambah: %d -> %d", saldoAwal.Tersedia, s.Tersedia)
	}
	// kode ambilnya udah ga bisa dipakai
	if _, err := x.l.AmbilDenganKode(ctx, ibis, *p1.Kode); kodeGalat(err) != http.StatusConflict {
		t.Fatalf("pindai kode lewat jam: %v", err)
	}
	// Bersihkan diulang ga ngubah apa-apa lagi
	x.l.Bersihkan(ctx)
	if q, _ := x.l.Satu(ctx, rani, p1.ID); q.Status != TidakDiambil {
		t.Fatalf("diulang: %s", q.Status)
	}
}

func TestLewatAmbilIkutJamDemo(t *testing.T) {
	jam := &jamTes{t: time.Date(2026, 10, 20, 20, 0, 0, 0, wita)}
	demo := 16*60 + 20
	l := &Layanan{Jam: jam.sekarang, JamDemo: &demo}
	p := Pesanan{Dibuat: time.Date(2026, 10, 20, 16, 0, 0, 0, wita), Tutup: 17 * 60}
	// jam asli udah 20.00, tapi server demo dikunci 16.20: belum lewat
	if l.lewatAmbil(p) {
		t.Fatal("server demo: pesanan sore jangan hangus")
	}
	// besoknya baru lewat
	jam.maju(24 * time.Hour)
	if !l.lewatAmbil(p) {
		t.Fatal("hari berikutnya harus lewat")
	}
}
