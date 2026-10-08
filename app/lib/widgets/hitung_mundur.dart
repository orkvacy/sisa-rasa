import 'dart:async';

import 'package:flutter/material.dart';

/// teks hitung mundur mm:ss sampai [batas], dipake buat batas bayar (F-40).
/// [onHabis] dipanggil sekali pas waktunya abis
class HitungMundur extends StatefulWidget {
  const HitungMundur({
    required this.batas,
    this.onHabis,
    this.style,
    super.key,
  });

  final DateTime batas;
  final VoidCallback? onHabis;
  final TextStyle? style;

  @override
  State<HitungMundur> createState() => _HitungMundurState();
}

class _HitungMundurState extends State<HitungMundur> {
  Timer? timer;
  Duration sisa = Duration.zero;
  bool sudahHabis = false;

  @override
  void initState() {
    super.initState();
    hitung();
    // Timer.periodic: ngitung ulang tiap detik
    timer = Timer.periodic(const Duration(seconds: 1), (_) => hitung());
  }

  void hitung() {
    final baru = widget.batas.difference(DateTime.now());
    if (baru <= Duration.zero) {
      timer?.cancel();
      if (!sudahHabis) {
        sudahHabis = true;
        // ditunda sampe frame selesai, biar onHabis boleh pindah halaman / kirim event
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onHabis?.call(),
        );
      }
      if (mounted) setState(() => sisa = Duration.zero);
      return;
    }
    if (mounted) setState(() => sisa = baru);
  }

  @override
  void dispose() {
    // timer wajib dimatiin, kalau ga tetep jalan walau halamannya udah ditutup
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menit = sisa.inMinutes.toString().padLeft(2, '0');
    final detik = (sisa.inSeconds % 60).toString().padLeft(2, '0');
    return Text('$menit:$detik', style: widget.style);
  }
}
