// Package config baca pengaturan server dari environment variable.
// rahasia (URL database, kunci API) cuma ada di sini, ga pernah di aplikasi (NF-16)
package config

import (
	"errors"
	"fmt"
	"os"
	"strings"
)

type Config struct {
	// alamat yang didengerin server, misal ":8080"
	Alamat string
	// postgres://user:sandi@host:5432/nama?sslmode=disable
	DatabaseURL string
	// "dev", "staging", atau "production"
	Lingkungan string
	// true kalau server di belakang proxy (Coolify/Traefik), IP asli dari X-Forwarded-For
	DiBelakangProxy bool
	// origin aplikasi web yg boleh manggil API (CORS), misal https://app.sisarasa.id.
	// di dev bawaannya "*"
	AsalWeb []string
	// bikin akun contoh (sandi sisarasa123). otomatis di dev,
	// di server demo dinyalain pakai SEMAI_AKUN_CONTOH=1. jangan di production
	SemaiAkunContoh bool
	// JamDemo kunci "jam sekarang" ke menit tertentu, sama kayak aplikasi demo
	// yang dikunci di 16.20. diisi lewat JAM_DEMO=16:20, kosong = jam asli
	JamDemo *int
	// QRISStatis QRIS statis merchant (isi teks QR-nya, bukan gambar).
	// kalau diisi, pesanan QRIS dapet QR asli dengan nominal pesanan
	QRISStatis string
	// FolderFoto tempat nyimpen foto paket kalau R2 belum diatur. di Coolify
	// folder ini harus dipasang Persistent Storage, kalau ga fotonya ilang tiap deploy
	FolderFoto string
	// Cloudflare R2 buat foto paket. kalau R2Bucket kosong, foto disimpan di FolderFoto
	R2IDAkun, R2Kunci, R2Rahasia, R2Bucket, R2Publik string
	// AdminEmail + AdminSandi bikin akun admin pas server nyala kalau belum ada.
	// sandinya cuma dipakai sekali, ganti nanti lewat fitur ganti sandi
	AdminEmail, AdminSandi string
	// GoogleClientID web client ID OAuth (boleh lebih dari satu, pisah koma).
	// kosong = masuk dengan Google dimatiin. ini bukan rahasia
	GoogleClientID []string
	// MidtransServerKey kunci rahasia Midtrans (isi di Coolify aja). kosong =
	// pembayaran mode uji. MidtransProduksi = pakai server produksi, bukan sandbox
	MidtransServerKey string
	MidtransProduksi  bool
}

func Baca() (Config, error) {
	c := Config{
		Alamat:          ambil("ALAMAT", ":8080"),
		DatabaseURL:     os.Getenv("DATABASE_URL"),
		Lingkungan:      ambil("LINGKUNGAN", "dev"),
		DiBelakangProxy: os.Getenv("DI_BELAKANG_PROXY") == "1",
	}
	c.SemaiAkunContoh = c.Dev() || os.Getenv("SEMAI_AKUN_CONTOH") == "1"
	if c.Dev() {
		c.AsalWeb = []string{"*"}
	}
	for _, asal := range strings.Split(os.Getenv("ASAL_WEB"), ",") {
		if asal = strings.TrimSpace(asal); asal != "" {
			c.AsalWeb = append(c.AsalWeb, asal)
		}
	}
	if v := os.Getenv("JAM_DEMO"); v != "" {
		var j, m int
		if _, err := fmt.Sscanf(v, "%d:%d", &j, &m); err != nil || j < 0 || j > 23 || m < 0 || m > 59 {
			return c, errors.New("JAM_DEMO harus berbentuk JJ:MM, misal 16:20")
		}
		menit := j*60 + m
		c.JamDemo = &menit
	}
	c.QRISStatis = strings.TrimSpace(os.Getenv("QRIS_STATIS"))
	c.FolderFoto = ambil("FOLDER_FOTO", "data/foto")
	c.AdminEmail = strings.TrimSpace(os.Getenv("ADMIN_EMAIL"))
	c.AdminSandi = os.Getenv("ADMIN_SANDI")
	for _, id := range strings.Split(os.Getenv("GOOGLE_CLIENT_ID"), ",") {
		if id = strings.TrimSpace(id); id != "" {
			c.GoogleClientID = append(c.GoogleClientID, id)
		}
	}
	c.MidtransServerKey = strings.TrimSpace(os.Getenv("MIDTRANS_SERVER_KEY"))
	c.MidtransProduksi = os.Getenv("MIDTRANS_PRODUKSI") == "1"
	// akun Midtrans lama: kunci sandbox diawali SB-. akun baru ga pakai awalan,
	// jadi cuma yang jelas sandbox (SB-) yang ditolak di mode produksi
	if c.MidtransProduksi && strings.HasPrefix(c.MidtransServerKey, "SB-") {
		return c, errors.New("MIDTRANS_SERVER_KEY ini kunci sandbox (diawali SB-), tapi MIDTRANS_PRODUKSI=1")
	}
	c.R2IDAkun = os.Getenv("R2_ID_AKUN")
	c.R2Kunci = os.Getenv("R2_ACCESS_KEY_ID")
	c.R2Rahasia = os.Getenv("R2_SECRET_ACCESS_KEY")
	c.R2Bucket = os.Getenv("R2_BUCKET")
	c.R2Publik = os.Getenv("R2_PUBLIK")
	if c.R2Bucket != "" && (c.R2IDAkun == "" || c.R2Kunci == "" || c.R2Rahasia == "" || c.R2Publik == "") {
		return c, errors.New("R2_BUCKET diisi tapi R2_ID_AKUN / R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY / R2_PUBLIK belum lengkap")
	}
	if c.DatabaseURL == "" {
		return c, errors.New("DATABASE_URL belum diisi")
	}
	if c.Lingkungan == "production" && (c.SemaiAkunContoh || c.JamDemo != nil) {
		return c, errors.New("SEMAI_AKUN_CONTOH dan JAM_DEMO ga boleh nyala di production")
	}
	return c, nil
}

func (c Config) Dev() bool { return c.Lingkungan == "dev" }

func ambil(kunci, bawaan string) string {
	if v := os.Getenv(kunci); v != "" {
		return v
	}
	return bawaan
}
