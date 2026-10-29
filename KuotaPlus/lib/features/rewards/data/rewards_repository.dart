import '../../../core/api_client.dart';
import '../../../core/format.dart';

class CalendarDay {
  const CalendarDay({required this.date, required this.result, required this.points});

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
        date: parseDate(json['date'] as String),
        result: json['result'] as String,
        points: json['points'] as int,
      );

  final DateTime date;

  /// hemat | boros | no_data
  final String result;
  final int points;
}

/// `GET /points` (FR-11.7).
class PointsSummary {
  const PointsSummary({
    required this.balance,
    required this.held,
    required this.streak,
    required this.calendar,
    required this.pointsPerDay,
    required this.streakBonus,
    required this.streakLength,
    required this.minUsageBytes,
    this.expiringPoints,
    this.firstExpiresAt,
  });

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    final expiring = json['expiring_soon'] as Map<String, dynamic>?;
    final rules = json['rules'] as Map<String, dynamic>;

    return PointsSummary(
      balance: json['balance'] as int,
      held: json['held'] as int,
      streak: json['streak'] as int,
      calendar: [for (final d in json['calendar'] as List) CalendarDay.fromJson(d as Map<String, dynamic>)],
      pointsPerDay: rules['points_per_day'] as int,
      streakBonus: rules['streak_bonus'] as int,
      streakLength: rules['streak_length'] as int,
      minUsageBytes: rules['min_usage_bytes'] as int,
      expiringPoints: expiring?['points'] as int?,
      firstExpiresAt: expiring == null ? null : parseDate(expiring['first_expires_at'] as String),
    );
  }

  final int balance;

  /// Ditahan transaksi yang belum dibayar; sudah tidak termasuk di [balance].
  final int held;
  final int streak;
  final List<CalendarDay> calendar;
  final int pointsPerDay;
  final int streakBonus;
  final int streakLength;
  final int minUsageBytes;

  /// Poin yang kedaluwarsa dalam 7 hari.
  final int? expiringPoints;
  final DateTime? firstExpiresAt;
}

class LedgerEntry {
  const LedgerEntry({required this.delta, required this.description, required this.createdAt, this.expiresAt});

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        delta: json['delta'] as int,
        description: json['description'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
      );

  final int delta;
  final String description;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

class LedgerPage {
  const LedgerPage(this.items, {required this.hasMore});

  final List<LedgerEntry> items;
  final bool hasMore;
}

class RewardsRepository {
  RewardsRepository(this._api);

  final ApiClient _api;

  Future<PointsSummary> summary() async {
    final body = await _api.get('/points');
    return PointsSummary.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<LedgerPage> ledger({int page = 1}) async {
    final body = await _api.get('/points/ledger', query: {'page': page}) as Map<String, dynamic>;
    final meta = body['meta'] as Map<String, dynamic>;
    return LedgerPage(
      [for (final e in body['data'] as List) LedgerEntry.fromJson(e as Map<String, dynamic>)],
      hasMore: (meta['current_page'] as int) < (meta['last_page'] as int),
    );
  }
}
