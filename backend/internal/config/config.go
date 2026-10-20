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
