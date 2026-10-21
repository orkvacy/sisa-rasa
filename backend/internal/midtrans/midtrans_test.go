package midtrans

import (
	"context"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/orkvacy/sisa-rasa/backend/internal/toko"
)

// midtransPalsu server tiruan Midtrans: nyatet request, jawab sesuai jalur
func midtransPalsu(t *testing.T, jawab func(r *http.Request, isi map[string]any) any) (*Klien, *[]map[string]any) {
	t.Helper()
	var diminta []map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if u, _, ok := r.BasicAuth(); !ok || u != "SB-Mid-server-rahasia" {
			t.Errorf("basic auth salah: %q", r.Header.Get("Authorization"))
		}
		isi := map[string]any{}
		_ = json.NewDecoder(r.Body).Decode(&isi)
		isi["_jalur"] = r.Method + " " + r.URL.Path
		diminta = append(diminta, isi)
		_ = json.NewEncoder(w).Encode(jawab(r, isi))
	}))
	t.Cleanup(srv.Close)
	return &Klien{ServerKey: "SB-Mid-server-rahasia", URLDasar: srv.URL}, &diminta
}

func TestTagih(t *testing.T) {
	k, diminta := midtransPalsu(t, func(r *http.Request, isi map[string]any) any {
		switch isi["payment_type"] {
		case "qris":
			return map[string]any{"status_code": "201", "qr_string": "00020101021226...6304ABCD",
				"actions": []map[string]string{{"name": "generate-qr-code", "url": "https://qr"}}}
		case "gopay":
			return map[string]any{"status_code": "201", "actions": []map[string]string{
				{"name": "generate-qr-code", "url": "https://qr"}, {"name": "deeplink-redirect", "url": "gojek://gopay/x"}}}
		case "bank_transfer":
			return map[string]any{"status_code": "201", "va_numbers": []map[string]string{{"bank": "bca", "va_number": "12345678901"}}}
		case "echannel":
			return map[string]any{"status_code": "201", "bill_key": "998877665544", "biller_code": "70012"}
		}
		return map[string]any{"status_code": "400", "status_message": "ga dikenal"}
	})
	ctx := context.Background()
	minta := func(metode string) map[string]string {
		t.Helper()
		h, err := k.Tagih(ctx, toko.PermintaanTagihan{IDTagihan: "id-" + metode, Total: 37400,
			Metode: metode, NamaPembeli: "Rani A.", BerlakuMenit: 14})
		if err != nil {
			t.Fatalf("%s: %v", metode, err)
		}
		if h["idTagihan"] != "id-"+metode || h["penyedia"] != "midtrans" {
			t.Errorf("%s: %v", metode, h)
		}
		return h
	}
	if h := minta("qris"); h["isiQr"] == "" {
		t.Errorf("qris tanpa isiQr: %v", h)
	}
	if h := minta("gopay"); h["tautan"] != "gojek://gopay/x" {
		t.Errorf("gopay tanpa tautan: %v", h)
	}
	if h := minta("va_bca"); h["nomorVa"] != "1234 5678 901" {
		t.Errorf("va bca: %v", h)
	}
	if h := minta("va_mandiri"); h["nomorVa"] != "9988 7766 5544" || h["kodePerusahaan"] != "70012" {
		t.Errorf("mandiri: %v", h)
	}
	// isi request: nominal, id, masa berlaku
	pertama := (*diminta)[0]
	detail := pertama["transaction_details"].(map[string]any)
	if pertama["_jalur"] != "POST /v2/charge" || detail["gross_amount"] != float64(37400) || detail["order_id"] != "id-qris" {
		t.Errorf("isi charge: %v", pertama)
	}
	if exp := pertama["custom_expiry"].(map[string]any); exp["expiry_duration"] != float64(14) {
		t.Errorf("masa berlaku: %v", exp)
	}

	// ditolak Midtrans -> galat
	k2, _ := midtransPalsu(t, func(*http.Request, map[string]any) any {
		return map[string]any{"status_code": "406", "status_message": "order_id sudah dipakai"}
	})
	if _, err := k2.Tagih(ctx, toko.PermintaanTagihan{IDTagihan: "x", Total: 1, Metode: "qris"}); err == nil {
		t.Error("charge ditolak harus galat")
	}
}

func TestStatus(t *testing.T) {
	kasus := map[string]struct {
		jawab map[string]any
		harap string
	}{
		"lunas":            {map[string]any{"status_code": "200", "transaction_status": "settlement", "gross_amount": "37400.00"}, toko.BayarLunas},
		"menunggu":         {map[string]any{"status_code": "201", "transaction_status": "pending", "gross_amount": "37400.00"}, toko.BayarMenunggu},
		"kedaluwarsa":      {map[string]any{"status_code": "407", "transaction_status": "expire", "gross_amount": "37400.00"}, toko.BayarGagal},
		"capture fraud":    {map[string]any{"status_code": "200", "transaction_status": "capture", "fraud_status": "challenge"}, toko.BayarMenunggu},
		"belum ada":        {map[string]any{"status_code": "404", "status_message": "not found"}, toko.BayarMenunggu},
		"capture diterima": {map[string]any{"status_code": "200", "transaction_status": "capture", "fraud_status": "accept", "gross_amount": "37400.00"}, toko.BayarLunas},
	}
	for nama, c := range kasus {
		t.Run(nama, func(t *testing.T) {
			k, diminta := midtransPalsu(t, func(*http.Request, map[string]any) any { return c.jawab })
			st, err := k.Status(context.Background(), "abc-1")
			if err != nil || st.Status != c.harap {
				t.Fatalf("dapet %+v %v, harusnya %s", st, err, c.harap)
			}
			if c.harap == toko.BayarLunas && st.Total != 37400 {
				t.Errorf("total: %d", st.Total)
			}
			if (*diminta)[0]["_jalur"] != "GET /v2/abc-1/status" {
				t.Errorf("jalur: %v", (*diminta)[0]["_jalur"])
			}
		})
	}
}

func TestSahNotifikasi(t *testing.T) {
	k := &Klien{ServerKey: "SB-Mid-server-rahasia"}
	h := sha512.Sum512([]byte("id-1" + "200" + "37400.00" + "SB-Mid-server-rahasia"))
	sah := toko.NotifikasiBayar{IDTagihan: "id-1", KodeStatus: "200", Total: "37400.00", TandaTangan: hex.EncodeToString(h[:])}
	if !k.SahNotifikasi(sah) {
		t.Fatal("tanda tangan asli ditolak")
	}
	palsu := sah
	palsu.Total = "1.00"
	if k.SahNotifikasi(palsu) {
		t.Error("nominal diubah tapi tanda tangan diterima")
	}
	palsu = sah
	palsu.TandaTangan = "abc"
	if k.SahNotifikasi(palsu) {
		t.Error("tanda tangan ngawur diterima")
	}
}
