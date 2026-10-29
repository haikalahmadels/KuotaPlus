/// Objek `Subscription`: paket milik pengguna (docs/API-KuotaPlus.md).
class Subscription {
  const Subscription({
    required this.id,
    required this.source,
    required this.name,
    required this.mainTotal,
    required this.mainRemaining,
    required this.appTotal,
    required this.appRemaining,
    required this.appCategory,
    required this.expiresAt,
    required this.status,
    this.sharedFrom,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as int,
        source: json['source'] as String,
        name: json['name'] as String,
        mainTotal: json['main_total'] as int,
        mainRemaining: json['main_remaining'] as int,
        appTotal: json['app_total'] as int,
        appRemaining: json['app_remaining'] as int,
        appCategory: json['app_category'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        status: json['status'] as String,
        sharedFrom: json['shared_from'] as String?,
      );

  final int id;

  /// purchase | shared
  final String source;
  final String name;
  final int mainTotal;
  final int mainRemaining;
  final int appTotal;
  final int appRemaining;

  /// video | sosmed | game | belajar, null jika tidak punya kuota aplikasi.
  final String? appCategory;
  final DateTime expiresAt;

  /// active | exhausted
  final String status;
  final String? sharedFrom;

  bool get isExhausted => status == 'exhausted';
}
