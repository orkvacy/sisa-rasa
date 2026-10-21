-- F-66 titik gerai buat ngitung jarak ke pembeli. jaraknya dihitung di HP,
-- lokasi pembeli ga pernah dikirim ke server
ALTER TABLE gerai ADD COLUMN lat DOUBLE PRECISION CHECK (lat BETWEEN -90 AND 90);
ALTER TABLE gerai ADD COLUMN lng DOUBLE PRECISION CHECK (lng BETWEEN -180 AND 180);
