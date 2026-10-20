package toko

import (
	"fmt"
	"strings"
	"testing"
)

// QRIS statis contoh (bukan merchant asli), CRC-nya dihitung ulang di tes
func qrisContoh() string {
	tlv := func(tag, nilai string) string { return fmt.Sprintf("%s%02d%s", tag, len(nilai), nilai) }
	isi := tlv("00", "01") + tlv("01", "11") +
		tlv("26", tlv("00", "ID.CO.CONTOH.WWW")+tlv("01", "ABCD1234")) +
		tlv("52", "8999") + tlv("53", "360") + tlv("58", "ID") +
		tlv("59", "CONTOH MERCHANT") + tlv("60", "SAMARINDA") + "6304"
	return isi + crc16(isi)
}

func TestCRC16(t *testing.T) {
	// nilai acuan CRC-16/CCITT-FALSE
	if got := crc16("123456789"); got != "29B1" {
		t.Fatalf("crc16: %s", got)
	}
}

func TestQRISDinamis(t *testing.T) {
	statis := qrisContoh()
	if err := CekQRIS(statis); err != nil {
		t.Fatal(err)
	}
	dinamis, err := QRISDinamis(statis, 74800)
	if err != nil {
		t.Fatal(err)
	}
	if err := CekQRIS(dinamis); err != nil {
		t.Fatalf("hasil ga valid: %v", err)
	}
	tag, _ := uraiQRIS(dinamis)
	urutan := []string{}
	nilai := map[string]string{}
	for _, x := range tag {
		urutan = append(urutan, x.tag)
		nilai[x.tag] = x.nilai
	}
	if nilai["01"] != "12" || nilai["54"] != "74800" {
		t.Fatalf("tag 01 / 54: %v", nilai)
	}
	// nominal tepat setelah mata uang, CRC paling akhir
	if got := strings.Join(urutan, ","); got != "00,01,26,52,53,54,58,59,60,63" {
		t.Fatalf("urutan tag: %s", got)
	}

	// nominal diganti: tag 54 lama dibuang, ga dobel
	lagi, _ := QRISDinamis(dinamis, 1000)
	if strings.Count(lagi, "5404") != 1 || CekQRIS(lagi) != nil {
		t.Fatalf("ganti nominal: %s", lagi)
	}

	if _, err := QRISDinamis(statis, 0); err == nil {
		t.Fatal("nominal 0 harus ditolak")
	}
	rusak := statis[:len(statis)-1] + "0"
	if CekQRIS(rusak) == nil {
		t.Fatal("CRC salah harus ketahuan")
	}
}
