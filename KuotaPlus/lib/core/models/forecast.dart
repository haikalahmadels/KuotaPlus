/// Objek `Forecast` (docs/API-KuotaPlus.md, FR-9).
class Forecast {
  const Forecast({
    required this.confidence,
    required this.status,
    required this.remainingBytes,
    required this.mainExpiresAt,
    this.avgDailyBytes,
    this.predictedEmptyAt,
    this.daysEarly,
  });

  factory Forecast.fromJson(Map<String, dynamic> json) => Forecast(
        confidence: json['confidence'] as String,
        status: json['status'] as String?,
        remainingBytes: json['remaining_bytes'] as int,
        mainExpiresAt: DateTime.parse(json['main_expires_at'] as String),
        avgDailyBytes: json['avg_daily_bytes'] as int?,
        predictedEmptyAt: json['predicted_empty_at'] == null ? null : DateTime.parse(json['predicted_empty_at'] as String),
        daysEarly: json['days_early'] as int?,
      );

  /// high | low ("perkiraan awal") | none (data < 3 hari)
  final String confidence;

  /// safe | risk | null jika confidence = none
  final String? status;
  final int remainingBytes;
  final DateTime mainExpiresAt;
  final int? avgDailyBytes;

  /// Null jika belum bisa diprediksi atau pemakaian 0 (aman sampai paket berakhir).
  final DateTime? predictedEmptyAt;
  final int? daysEarly;

  bool get isRisk => status == 'risk';
}
