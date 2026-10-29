import 'package:flutter/services.dart';

/// Pemakaian data seluler per aplikasi dari NetworkStatsManager (Android saja).
abstract final class UsageStats {
  static const _channel = MethodChannel('kuotaplus/usage_stats');

  /// Izin "Usage Access" (PACKAGE_USAGE_STATS) sudah diberikan di Settings.
  static Future<bool> hasUsageAccess() async => await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  /// Membuka halaman Settings tempat pengguna memberi izin Usage Access.
  static Future<void> openUsageAccessSettings() => _channel.invokeMethod<void>('openUsageAccessSettings');

  /// Satu entri per aplikasi per hari untuk [days] hari terakhir (hari ini termasuk), batas hari WIB.
  /// Bentuknya sama dengan bucket `POST /usage/sync`: `usage_date`, `package_name`, `label`, `bytes_mobile`.
  static Future<List<Map<String, Object>>> queryDailyMobileUsage({int days = 7}) async {
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>('queryDailyMobileUsage', {'days': days});
    return [for (final bucket in result ?? const []) bucket.cast<String, Object>()];
  }
}
