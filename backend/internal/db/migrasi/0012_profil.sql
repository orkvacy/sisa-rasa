-- F-63 foto profil. isinya URL foto di R2 / disk yang diunggah lewat
-- POST /v1/akun/foto, NULL = pakai inisial nama
ALTER TABLE akun ADD COLUMN foto TEXT;
