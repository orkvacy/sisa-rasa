package toko

import (
	"errors"
	"fmt"
	"strconv"
)

// QRIS (standar EMVCo) isinya deretan tag-panjang-nilai, misal "5303360" =
// tag 53, panjang 03, nilai "360". QRIS statis bisa dijadiin dinamis dengan:
//   - tag 01 "11" (statis) diganti "12" (dinamis)
//   - tag 54 (nominal) disisipin setelah tag 53 (mata uang)
//   - tag 63 (CRC16-CCITT) dihitung ulang
// hasilnya waktu di-scan, nominal di aplikasi e-wallet / m-banking udah keisi

type tagQRIS struct{ tag, nilai string }

func uraiQRIS(qris string) ([]tagQRIS, error) {
	var hasil []tagQRIS
	for i := 0; i < len(qris); {
		if i+4 > len(qris) {
			return nil, errors.New("QRIS terpotong")
		}
		n, err := strconv.Atoi(qris[i+2 : i+4])
		if err != nil || i+4+n > len(qris) {
			return nil, errors.New("panjang tag QRIS tidak valid")
		}
		hasil = append(hasil, tagQRIS{qris[i : i+2], qris[i+4 : i+4+n]})
		i += 4 + n
	}
	return hasil, nil
}

// crc16 CRC16-CCITT (poly 0x1021, awal 0xFFFF) yang dipakai QRIS
func crc16(data string) string {
	c := uint16(0xFFFF)
	for i := 0; i < len(data); i++ {
		c ^= uint16(data[i]) << 8
		for range 8 {
			if c&0x8000 != 0 {
				c = c<<1 ^ 0x1021
			} else {
				c <<= 1
			}
		}
	}
	return fmt.Sprintf("%04X", c)
}

// CekQRIS mastiin string QRIS bisa diurai dan CRC-nya benar. dipanggil sekali
// pas server nyala, biar QRIS_STATIS yang salah ketik langsung ketahuan
func CekQRIS(qris string) error {
	tag, err := uraiQRIS(qris)
	if err != nil {
		return err
	}
	if len(tag) == 0 || tag[len(tag)-1].tag != "63" {
		return errors.New("QRIS tidak diakhiri CRC (tag 63)")
	}
	if crc16(qris[:len(qris)-4]) != tag[len(tag)-1].nilai {
		return errors.New("CRC QRIS tidak cocok, cek lagi isinya")
	}
	return nil
}

// QRISDinamis QRIS statis [statis] dengan nominal [rupiah] di dalamnya
func QRISDinamis(statis string, rupiah int) (string, error) {
	if rupiah <= 0 {
		return "", errors.New("nominal harus lebih dari 0")
	}
	tag, err := uraiQRIS(statis)
	if err != nil {
		return "", err
	}
	nominal := strconv.Itoa(rupiah)
	sisip := func(b []byte) []byte { return fmt.Appendf(b, "54%02d%s", len(nominal), nominal) }

	var hasil []byte
	disisip := false
	for _, t := range tag {
		switch t.tag {
		case "54", "63":
			continue // nominal lama dan CRC lama dibuang
		case "01":
			t.nilai = "12"
		case "58":
			if !disisip { // QRIS tanpa tag 53: nominal tetap sebelum kode negara
				hasil, disisip = sisip(hasil), true
			}
		}
		hasil = fmt.Appendf(hasil, "%s%02d%s", t.tag, len(t.nilai), t.nilai)
		if t.tag == "53" && !disisip {
			hasil, disisip = sisip(hasil), true
		}
	}
	if !disisip {
		hasil = sisip(hasil)
	}
	hasil = append(hasil, "6304"...)
	return string(hasil) + crc16(string(hasil)), nil
}
