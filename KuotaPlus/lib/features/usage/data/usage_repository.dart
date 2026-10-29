import '../../../core/api_client.dart';
import '../../../core/format.dart';

/// Satu baris aplikasi di analisis. [appId] null untuk baris "Lainnya".
class AppUsage {
  const AppUsage({
    required this.appId,
    required this.label,
    required this.category,
    required this.bytes,
    required this.percent,
  });

  factory AppUsage.fromJson(Map<String, dynamic> json) => AppUsage(
        appId: json['app_id'] as int?,
        label: json['label'] as String,
        category: json['category'] as String?,
        bytes: json['bytes'] as int,
        percent: (json['percent'] as num).toDouble(),
      );

  final int? appId;
  final String label;
  final String? category;
  final int bytes;
  final double percent;
}

class DailyUsage {
  const DailyUsage({required this.date, required this.bytes, this.budgetBytes, this.isSpike = false});

  factory DailyUsage.fromJson(Map<String, dynamic> json) => DailyUsage(
        date: parseDate(json['date'] as String),
        bytes: json['bytes'] as int,
        budgetBytes: json['budget_bytes'] as int?,
        isSpike: json['is_spike'] as bool? ?? false,
      );

  final DateTime date;
  final int bytes;
  final int? budgetBytes;
  final bool isSpike;
}

/// `GET /usage/summary` (docs/API-KuotaPlus.md).
class UsageSummary {
  const UsageSummary({
    required this.period,
    required this.source,
    required this.lastSyncedAt,
    required this.totalBytes,
    required this.topApps,
    required this.apps,
    required this.daily,
    required this.insights,
  });

  factory UsageSummary.fromJson(Map<String, dynamic> json) => UsageSummary(
        period: json['period'] as String,
        source: json['source'] as String?,
        lastSyncedAt: json['last_synced_at'] == null ? null : DateTime.parse(json['last_synced_at'] as String),
        totalBytes: json['total_bytes'] as int,
        topApps: [for (final a in json['top_apps'] as List) AppUsage.fromJson(a as Map<String, dynamic>)],
        apps: [for (final a in json['apps'] as List) AppUsage.fromJson(a as Map<String, dynamic>)],
        daily: [for (final d in json['daily'] as List) DailyUsage.fromJson(d as Map<String, dynamic>)],
        insights: (json['insights'] as List).cast<String>(),
      );

  final String period;

  /// device | demo | null (belum ada data sama sekali)
  final String? source;
  final DateTime? lastSyncedAt;
  final int totalBytes;
  final List<AppUsage> topApps;
  final List<AppUsage> apps;
  final List<DailyUsage> daily;
  final List<String> insights;

  bool get hasData => source != null;
}

/// `GET /usage/apps/{id}`.
class AppUsageDetail {
  const AppUsageDetail({
    required this.label,
    required this.category,
    required this.totalBytes,
    required this.avgDailyBytes,
    required this.daily,
  });

  factory AppUsageDetail.fromJson(Map<String, dynamic> json) => AppUsageDetail(
        label: json['app']['label'] as String,
        category: json['app']['category'] as String,
        totalBytes: json['total_bytes'] as int,
        avgDailyBytes: json['avg_daily_bytes'] as int,
        daily: [for (final d in json['daily'] as List) DailyUsage.fromJson(d as Map<String, dynamic>)],
      );

  final String label;
  final String category;
  final int totalBytes;
  final int avgDailyBytes;
  final List<DailyUsage> daily;
}

class UsageRepository {
  UsageRepository(this._api);

  final ApiClient _api;

  Future<UsageSummary> summary(String period) async {
    final body = await _api.get('/usage/summary', query: {'period': period});
    return UsageSummary.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<AppUsageDetail> app(int appId, String period) async {
    final body = await _api.get('/usage/apps/$appId', query: {'period': period});
    return AppUsageDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Mode Demo (FR-7.8). [profile]: rina | budi | random. Memanggil lagi = ganti profil.
  Future<void> generateDemo(String profile) => _api.post('/usage/demo', data: {'profile': profile});
}
