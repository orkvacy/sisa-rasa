import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sisa_rasa/core/theme/warna.dart';
import 'package:sisa_rasa/domain/repositories/layanan_lokasi.dart';
import 'package:sisa_rasa/presentation/cubit/lokasi_cubit.dart';

/// buka peta buat milih titik lokasi manual (F-66). dipakai pembeli yang
/// GPS-nya mati / mau liat jarak dari tempat lain, dan mitra yang lagi ga di
/// gerai. balikin null kalau ditutup tanpa milih
Future<Posisi?> pilihTitik(
  BuildContext context, {
  required String judul,
  Posisi? awal,
}) {
  return Navigator.of(context, rootNavigator: true).push<Posisi>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(
        value: context.read<LokasiCubit>(),
        child: PilihTitik(judul: judul, awal: awal),
      ),
    ),
  );
}

/// peta OpenStreetMap, pin diam di tengah: petanya yang digeser
class PilihTitik extends StatefulWidget {
  const PilihTitik({required this.judul, this.awal, super.key});

  final String judul;
  final Posisi? awal;

  /// tengah Samarinda, dipakai kalau belum ada titik sama sekali
  static const samarinda = Posisi(-0.5022, 117.1537);

  @override
  State<PilihTitik> createState() => _PilihTitikState();
}

class _PilihTitikState extends State<PilihTitik> {
  final _peta = MapController();
  late LatLng _tengah;
  bool _mencari = false;

  @override
  void initState() {
    super.initState();
    final awal = widget.awal ?? PilihTitik.samarinda;
    _tengah = LatLng(awal.lat, awal.lng);
  }

  @override
  void dispose() {
    _peta.dispose();
    super.dispose();
  }

  /// lompat ke GPS HP, titiknya tetap bisa digeser lagi
  Future<void> _keLokasiSaya() async {
    setState(() => _mencari = true);
    try {
      final p = await context.read<LokasiCubit>().layanan.posisiSaya();
      if (!mounted) return;
      _tengah = LatLng(p.lat, p.lng);
      _peta.move(_tengah, 17);
    } on GagalLokasi catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.pesan)));
    } finally {
      if (mounted) setState(() => _mencari = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Warna.latar,
      appBar: AppBar(
        backgroundColor: Warna.latar,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.judul,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _peta,
            options: MapOptions(
              initialCenter: _tengah,
              initialZoom: widget.awal == null ? 13 : 17,
              minZoom: 5,
              maxZoom: 19,
              // putar peta dimatiin, bikin bingung pas nyari titik
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (kamera, _) => _tengah = kamera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.orkvacy.sisa_rasa',
              ),
              // wajib dari OSM. versi lipat (ikon "i") biar ga meluber di HP sempit
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          // pin di tengah, ujung bawahnya pas di titik yang dipilih
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: Warna.hijau),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Material(
              color: Colors.white,
              elevation: 1,
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'Geser peta sampai pin tepat di lokasi.',
                  style: TextStyle(fontSize: 13, color: Warna.teks),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                key: const Key('titik-gps'),
                onPressed: _mencari ? null : _keLokasiSaya,
                icon: _mencari
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('Lokasi saya'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Warna.hijau,
                  minimumSize: const Size(0, 48),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('pakai-titik'),
                  onPressed: () => Navigator.pop(
                    context,
                    Posisi(_tengah.latitude, _tengah.longitude),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Warna.hijau,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Pakai titik ini'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
