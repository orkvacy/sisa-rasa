/// status pesanan sesuai F-41 di SRS.
/// disimpen sebagai string di map pesanan, labelnya dikumpulin di sini
/// biar kalau nama tahapannya diganti cukup ubah satu tempat
abstract final class StatusPesanan {
  static const menungguBayar = 'menunggu_bayar';
  static const disiapkan = 'disiapkan';
  static const siapDiambil = 'siap_diambil';
  static const selesai = 'selesai';
  static const dibatalkan = 'dibatalkan';
  static const tidakDiambil = 'tidak_diambil';

  static const _label = {
    menungguBayar: 'Menunggu pembayaran',
    disiapkan: 'Disiapkan',
    siapDiambil: 'Siap diambil',
    selesai: 'Selesai',
    dibatalkan: 'Dibatalkan',
    tidakDiambil: 'Tidak diambil',
  };

  static String label(String status) => _label[status] ?? status;

  /// masuk segmen Berlangsung di tab pesanan (F-12)
  static bool berlangsung(String status) =>
      status == menungguBayar || status == disiapkan || status == siapDiambil;
}
