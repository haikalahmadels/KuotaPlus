import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../app/theme.dart';
import '../../../core/platform.dart';
import 'usage_charts.dart';

/// Logo asli aplikasi (masukan pengguna M10):
/// 1. Android: ikon dari aplikasi yang terpasang di HP (PackageManager), berlaku untuk aplikasi apa pun.
/// 2. Web, data demo, atau aplikasi yang sudah dihapus: logo resmi yang dibundel di assets/app_logos.
/// 3. Tidak ada keduanya: huruf awal di kotak berwarna. "Lainnya" dan grup sistem memakai ikon kategori.
class AppLogo extends StatefulWidget {
  const AppLogo({super.key, required this.packageName, required this.label, this.size = 36, this.category});

  final String? packageName;
  final String label;
  final String? category;
  final double size;

  /// Logo resmi yang ikut di aset (sumber svgl.app). Shopee dan Mobile Legends tidak tersedia di sana.
  static const bundled = {
    'com.whatsapp',
    'com.google.android.youtube',
    'com.zhiliaoapp.musically',
    'com.instagram.android',
    'com.google.android.apps.maps',
    'com.google.android.gm',
    'com.android.chrome',
    'us.zoom.videomeetings',
  };

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> {
  /// Ikon perangkat per package; null = aplikasi tidak terpasang. Dibagi antar layar selama aplikasi berjalan.
  static final _deviceIcons = <String, Future<Uint8List?>>{};

  Future<Uint8List?>? _icon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AppLogo old) {
    super.didUpdateWidget(old);
    if (old.packageName != widget.packageName) _load();
  }

  void _load() {
    final pkg = widget.packageName;
    _icon = pkg != null && isAndroidApp && !pkg.startsWith('android.')
        ? _deviceIcons.putIfAbsent(pkg, () => UsageStats.getAppIcon(pkg, size: 128).catchError((_) => null))
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = BorderRadius.circular(size * 0.28);

    Widget fallback() {
      final pkg = widget.packageName;
      if (pkg != null && AppLogo.bundled.contains(pkg)) {
        return Container(
          padding: EdgeInsets.all(size * 0.14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: radius, border: Border.all(color: AppColors.border)),
          child: SvgPicture.asset('assets/app_logos/$pkg.svg', fit: BoxFit.contain),
        );
      }
      final generic = pkg == null || pkg.startsWith('android.');
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: radius),
        child: generic
            ? Icon(categoryIcons[widget.category] ?? Icons.apps_rounded, color: AppColors.primary, size: size * 0.55)
            : Text(
                widget.label.characters.first.toUpperCase(),
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: size * 0.42),
              ),
      );
    }

    final logo = _icon == null
        ? fallback()
        : FutureBuilder<Uint8List?>(
            future: _icon,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return snapshot.connectionState == ConnectionState.done
                    ? fallback()
                    : DecoratedBox(decoration: BoxDecoration(color: AppColors.neutralContainer, borderRadius: radius));
              }
              return ClipRRect(borderRadius: radius, child: Image.memory(bytes, gaplessPlayback: true));
            },
          );

    // Nama aplikasi selalu tertulis di sebelahnya, jadi logo dekoratif bagi pembaca layar.
    return ExcludeSemantics(child: SizedBox.square(dimension: size, child: logo));
  }
}
