import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../core/api_client.dart';
import '../../home/providers.dart';
import '../data/device_usage.dart';
import '../providers.dart';

const _seenKey = 'usage_onboarding_seen';

/// Layar izin otomatis hanya ditawarkan sekali; setelah itu lewat tombol "Beri izin" di Analisis.
Future<bool> usageOnboardingSeen() async => (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;

/// S03: penjelasan sebelum membuka Settings "Usage Access" (FR-7.1, US-17).
class UsageAccessScreen extends ConsumerStatefulWidget {
  const UsageAccessScreen({super.key});

  @override
  ConsumerState<UsageAccessScreen> createState() => _UsageAccessScreenState();
}

class _UsageAccessScreenState extends ConsumerState<UsageAccessScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_seenKey, true));
    _lifecycle = AppLifecycleListener(onResume: _checkAfterSettings);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    _waitingForSettings = true;
    await UsageStats.openUsageAccessSettings();
  }

  /// Kembali dari Settings: jika izin sudah diberikan, langsung sync lalu tutup layar ini.
  Future<void> _checkAfterSettings() async {
    if (!_waitingForSettings) return;
    _waitingForSettings = false;
    if (!await hasUsageAccess()) return;

    await reportAndSyncUsage(ref.read(apiClientProvider));
    ref
      ..invalidate(usageAccessProvider)
      ..invalidate(usageSummaryProvider)
      ..invalidate(homeProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(title, style: theme.textTheme.labelLarge), Text(body, style: muted)],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Izin data pemakaian')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Lihat aplikasi mana yang menghabiskan kuotamu', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Kuota+ butuh izin "Akses penggunaan" untuk menghitung pemakaian data seluler per aplikasi.', style: muted),
            const SizedBox(height: 24),
            point(Icons.check_circle_outline, 'Yang dibaca',
                'Jumlah byte data seluler per aplikasi per hari. Pemakaian Wi-Fi tidak dihitung.'),
            point(Icons.block, 'Yang tidak dibaca',
                'Isi trafik, pesan, riwayat browsing, atau apa pun yang kamu lakukan di dalam aplikasi.'),
            point(Icons.lock_outline, 'Ke mana datanya',
                'Hanya dikirim ke server Kuota+ untuk analisis, prediksi, dan rekomendasi paket.'),
            const SizedBox(height: 8),
            Text('Di halaman pengaturan berikutnya, pilih Kuota+ lalu aktifkan izinnya, kemudian kembali ke aplikasi ini.',
                style: muted),
            const SizedBox(height: 24),
            FilledButton(onPressed: _openSettings, child: const Text('Buka pengaturan izin')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => context.go('/usage'), child: const Text('Pakai Mode Demo')),
            TextButton(onPressed: () => context.pop(), child: const Text('Nanti saja')),
          ],
        ),
      ),
    );
  }
}
