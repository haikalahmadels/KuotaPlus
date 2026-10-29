import 'package:usage_stats/usage_stats.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/platform.dart';

/// Izin Usage Access. Selalu false di web (FR-7: hanya Android yang bisa membaca pemakaian per aplikasi).
Future<bool> hasUsageAccess() async => isAndroidApp && await UsageStats.hasUsageAccess();

/// Melaporkan status izin (metrik admin) lalu mengirim pemakaian 7 hari terakhir ke server (FR-7.5).
/// Dipakai saat aplikasi dibuka dan oleh WorkManager tiap 6 jam, jadi tidak bergantung pada Riverpod.
/// Mengembalikan true jika data terkirim.
Future<bool> reportAndSyncUsage(ApiClient api) async {
  final granted = await hasUsageAccess();

  try {
    await api.put('/device', data: {'platform': isAndroidApp ? 'android' : 'web', 'usage_access_granted': granted});
    if (!granted) return false;

    final buckets = await UsageStats.queryDailyMobileUsage(days: 7);
    await api.post('/usage/sync', data: {'buckets': buckets});
    return true;
  } on ApiException {
    // Gagal diam-diam: dicoba lagi saat aplikasi dibuka berikutnya atau oleh jadwal 6 jam (edge case Izin).
    return false;
  }
}
