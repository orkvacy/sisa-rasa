package foto

import (
	"bytes"
	"context"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// R2 nyimpen foto di bucket Cloudflare R2 (API-nya kompatibel S3).
// foto disajikan langsung dari domain publik bucket (misal https://cdn.sisarasa.web.id)
// lewat CDN Cloudflare, ga lewat server ini sama sekali
type R2 struct {
	klien  *minio.Client
	bucket string
	publik string
}

// BukaR2 sambung ke bucket. [publik] alamat publik bucket tanpa garis miring di akhir
func BukaR2(idAkun, kunci, rahasia, bucket, publik string) (*R2, error) {
	klien, err := minio.New(idAkun+".r2.cloudflarestorage.com", &minio.Options{
		Creds:  credentials.NewStaticV4(kunci, rahasia, ""),
		Secure: true,
		Region: "auto",
	})
	if err != nil {
		return nil, err
	}
	return &R2{klien: klien, bucket: bucket, publik: strings.TrimRight(publik, "/")}, nil
}

func (r *R2) Taruh(ctx context.Context, nama string, isi []byte) (string, error) {
	_, err := r.klien.PutObject(ctx, r.bucket, "paket/"+nama, bytes.NewReader(isi), int64(len(isi)),
		minio.PutObjectOptions{
			ContentType: "image/jpeg",
			// nama file acak dan isinya ga pernah berubah: boleh di-cache selamanya
			CacheControl: "public, max-age=31536000, immutable",
		})
	if err != nil {
		return "", err
	}
	return r.publik + "/paket/" + nama, nil
}

func (r *R2) Sah(url string) bool {
	nama, ada := strings.CutPrefix(url, r.publik+"/paket/")
	return ada && polaNama.MatchString(nama)
}
