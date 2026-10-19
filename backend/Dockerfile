# server Sisa Rasa. dibangun dari folder backend/:
#   docker build -t sisarasa-api .
# di Coolify: Base Directory = /backend, Build Pack = Dockerfile, port 8080

FROM golang:1.27-alpine AS bangun
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# binary statis, tanpa info debug biar kecil
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /server ./cmd/server

FROM alpine:3.22
# ca-certificates buat koneksi https keluar (Midtrans, Resend) nanti;
# wget bawaan busybox dipakai healthcheck
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 sisarasa
COPY --from=bangun /server /usr/local/bin/server
USER sisarasa
ENV ALAMAT=:8080 LINGKUNGAN=production DI_BELAKANG_PROXY=1 TZ=Asia/Makassar
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["/usr/local/bin/server"]
