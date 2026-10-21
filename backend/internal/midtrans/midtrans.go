// Package midtrans penyedia pembayaran Sisa Rasa lewat Midtrans Core API
// (QRIS, GoPay, virtual account). dipasang ke toko.Layanan.Gerbang.
//
// alurnya: server minta tagihan (/v2/charge) -> pembeli bayar -> Midtrans
// manggil webhook POST /v1/pembayaran/midtrans -> server ngecek tanda tangan,
// nanya ulang status (/v2/{id}/status), baru pesanan ditandai lunas
package midtrans

import (
	"bytes"
	"context"
	"crypto/sha512"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/orkvacy/sisa-rasa/backend/internal/toko"
)

// Klien pemanggil Midtrans. ServerKey rahasia, cuma ada di env server
type Klien struct {
	ServerKey string
	// Produksi true = api.midtrans.com, selain itu sandbox (uang bohongan)
	Produksi bool
	// URLDasar buat tes, kosong = sesuai Produksi
	URLDasar string
	HTTP     *http.Client
}

var _ toko.Gerbang = (*Klien)(nil)

func (k *Klien) dasar() string {
	switch {
	case k.URLDasar != "":
		return k.URLDasar
	case k.Produksi:
		return "https://api.midtrans.com"
	}
	return "https://api.sandbox.midtrans.com"
}

func (k *Klien) http() *http.Client {
	if k.HTTP != nil {
		return k.HTTP
	}
	return &http.Client{Timeout: 15 * time.Second}
}

// jawaban Midtrans. status_code di dalam isi yang nentuin berhasil atau ga,
// HTTP-nya sering tetap 200
type jawaban struct {
	StatusCode        string `json:"status_code"`
	StatusMessage     string `json:"status_message"`
	TransactionStatus string `json:"transaction_status"`
	FraudStatus       string `json:"fraud_status"`
	GrossAmount       string `json:"gross_amount"`
	QRString          string `json:"qr_string"`
	BillKey           string `json:"bill_key"`
	BillerCode        string `json:"biller_code"`
	VANumbers         []struct {
		Bank     string `json:"bank"`
		VANumber string `json:"va_number"`
	} `json:"va_numbers"`
	Actions []struct {
		Name string `json:"name"`
		URL  string `json:"url"`
	} `json:"actions"`
}

func (k *Klien) kirim(ctx context.Context, metode, jalur string, isi any) (jawaban, error) {
	var badan io.Reader
	if isi != nil {
		b, err := json.Marshal(isi)
		if err != nil {
			return jawaban{}, err
		}
		badan = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, metode, k.dasar()+jalur, badan)
	if err != nil {
		return jawaban{}, err
	}
	req.SetBasicAuth(k.ServerKey, "")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	res, err := k.http().Do(req)
	if err != nil {
		return jawaban{}, fmt.Errorf("midtrans: %w", err)
	}
	defer res.Body.Close()
	var j jawaban
	if err := json.NewDecoder(io.LimitReader(res.Body, 1<<20)).Decode(&j); err != nil {
		return jawaban{}, fmt.Errorf("midtrans: jawaban ga kebaca (HTTP %d): %w", res.StatusCode, err)
	}
	return j, nil
}

// bank virtual account per metode aplikasi. Mandiri lewat echannel (bill payment)
var bankVA = map[string]string{"va_bca": "bca", "va_bri": "bri", "va_bni": "bni"}

func (k *Klien) Tagih(ctx context.Context, t toko.PermintaanTagihan) (map[string]string, error) {
	isi := map[string]any{
		"transaction_details": map[string]any{"order_id": t.IDTagihan, "gross_amount": t.Total},
		"custom_expiry":       map[string]any{"expiry_duration": t.BerlakuMenit, "unit": "minute"},
		"customer_details":    map[string]any{"first_name": t.NamaPembeli},
	}
	switch {
	case t.Metode == "qris":
		isi["payment_type"] = "qris"
		isi["qris"] = map[string]any{"acquirer": "gopay"}
	case t.Metode == "gopay":
		isi["payment_type"] = "gopay"
	case t.Metode == "va_mandiri":
		isi["payment_type"] = "echannel"
		isi["echannel"] = map[string]any{"bill_info1": "Pembayaran:", "bill_info2": "Sisa Rasa"}
	case bankVA[t.Metode] != "":
		isi["payment_type"] = "bank_transfer"
		isi["bank_transfer"] = map[string]any{"bank": bankVA[t.Metode]}
	default:
		return nil, fmt.Errorf("midtrans: metode %q belum didukung", t.Metode)
	}

	j, err := k.kirim(ctx, http.MethodPost, "/v2/charge", isi)
	if err != nil {
		return nil, err
	}
	if j.StatusCode != "201" && j.StatusCode != "200" {
		return nil, fmt.Errorf("midtrans: charge ditolak %s: %s", j.StatusCode, j.StatusMessage)
	}

	hasil := map[string]string{"idTagihan": t.IDTagihan, "penyedia": "midtrans"}
	for _, a := range j.Actions {
		switch a.Name {
		case "deeplink-redirect":
			hasil["tautan"] = a.URL
		case "generate-qr-code":
			hasil["urlQr"] = a.URL
		}
	}
	switch {
	case j.QRString != "":
		hasil["isiQr"] = j.QRString
	case j.BillKey != "":
		hasil["nomorVa"] = kelompok(j.BillKey)
		hasil["kodePerusahaan"] = j.BillerCode
	case len(j.VANumbers) > 0:
		hasil["nomorVa"] = kelompok(j.VANumbers[0].VANumber)
	}
	if t.Metode == "qris" && hasil["isiQr"] == "" {
		return nil, errors.New("midtrans: QRIS tanpa qr_string")
	}
	if strings.HasPrefix(t.Metode, "va_") && hasil["nomorVa"] == "" {
		return nil, errors.New("midtrans: VA tanpa nomor")
	}
	return hasil, nil
}

// kelompok "12345678901" jadi "1234 5678 901", biar gampang dibaca
func kelompok(nomor string) string {
	var b strings.Builder
	for i, c := range nomor {
		if i > 0 && i%4 == 0 {
			b.WriteByte(' ')
		}
		b.WriteRune(c)
	}
	return b.String()
}

func (k *Klien) Status(ctx context.Context, idTagihan string) (toko.StatusBayar, error) {
	j, err := k.kirim(ctx, http.MethodGet, "/v2/"+idTagihan+"/status", nil)
	if err != nil {
		return toko.StatusBayar{}, err
	}
	if j.StatusCode == "404" {
		// belum ada transaksinya di Midtrans
		return toko.StatusBayar{Status: toko.BayarMenunggu}, nil
	}
	total, _ := strconv.ParseFloat(j.GrossAmount, 64)
	st := toko.StatusBayar{Status: toko.BayarMenunggu, Total: int(math.Round(total))}
	switch j.TransactionStatus {
	case "settlement":
		st.Status = toko.BayarLunas
	case "capture":
		// kartu kredit: capture baru lunas kalau lolos cek fraud
		if j.FraudStatus == "accept" {
			st.Status = toko.BayarLunas
		}
	case "expire", "cancel", "deny", "failure":
		st.Status = toko.BayarGagal
	case "":
		return toko.StatusBayar{}, fmt.Errorf("midtrans: status %s: %s", j.StatusCode, j.StatusMessage)
	}
	return st, nil
}

func (k *Klien) Batalkan(ctx context.Context, idTagihan string) error {
	j, err := k.kirim(ctx, http.MethodPost, "/v2/"+idTagihan+"/cancel", nil)
	if err != nil {
		return err
	}
	if j.StatusCode != "200" && j.StatusCode != "412" && j.StatusCode != "404" {
		return fmt.Errorf("midtrans: batal %s: %s", j.StatusCode, j.StatusMessage)
	}
	return nil
}

// SahNotifikasi signature_key = SHA512(order_id + status_code + gross_amount + server key)
func (k *Klien) SahNotifikasi(n toko.NotifikasiBayar) bool {
	h := sha512.Sum512([]byte(n.IDTagihan + n.KodeStatus + n.Total + k.ServerKey))
	harap := hex.EncodeToString(h[:])
	return subtle.ConstantTimeCompare([]byte(harap), []byte(strings.ToLower(n.TandaTangan))) == 1
}
