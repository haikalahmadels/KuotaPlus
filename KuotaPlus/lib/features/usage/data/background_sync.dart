import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';
import 'device_usage.dart';

const _syncTask = 'kuotaplus.usageSync';

/// Dijalankan WorkManager di engine Flutter terpisah, tanpa UI dan tanpa Riverpod.
@pragma('vm:entry-point')
void usageSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    final tokens = TokenStorage();
    if (await tokens.read() == null) return true; // belum login: tidak ada yang dikirim

    // FR-13.2: alert hasil sync latar belakang tampil sebagai notifikasi lokal di dalam fungsi ini.
    await reportAndSyncUsage(ApiClient(tokens));
    return true;
  });
}

/// Sync tiap 6 jam (FR-7.5). Dipanggil sekali saat aplikasi Android dibuka; jadwal yang sudah ada dipertahankan.
Future<void> scheduleUsageSync() async {
  await Workmanager().initialize(usageSyncDispatcher);
  await Workmanager().registerPeriodicTask(
    _syncTask,
    _syncTask,
    frequency: const Duration(hours: 6),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
