/// Objek bersama `Alert` (docs/API-KuotaPlus.md, FR-13): dari `GET /home` dan `POST /usage/sync`,
/// sudah lolos batas 1 per jenis per hari dan hanya dikirim sekali.
class Alert {
  const Alert({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.target,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as int,
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        target: json['target'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static List<Alert> listFromJson(Object? json) =>
      [for (final a in json as List? ?? const []) Alert.fromJson(a as Map<String, dynamic>)];

  final int id;

  /// quota_low | forecast_risk | package_expiring | card_expiring | transaction_status | quota_received
  final String kind;
  final String title;
  final String body;

  /// Route go_router yang dibuka saat alert diketuk (FR-13.3).
  final String target;
  final DateTime createdAt;
}
