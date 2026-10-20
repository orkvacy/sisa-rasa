-- F-30b masuk dengan Google. akun Google disimpan pakai sub (id akun Google),
-- bukan email, soalnya email Google bisa diganti pemiliknya.
-- akun yang dibikin lewat Google hash_sandi-nya '' (ga bisa masuk pakai sandi)
ALTER TABLE akun ADD COLUMN google_sub TEXT UNIQUE;
