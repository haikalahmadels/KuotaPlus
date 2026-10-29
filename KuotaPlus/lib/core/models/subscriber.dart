import '../format.dart';

/// Objek `Subscriber` (docs/API-KuotaPlus.md).
class Subscriber {
  const Subscriber({
    required this.msisdn,
    required this.pulsaBalance,
    required this.status,
    required this.activeUntil,
    required this.daysLeft,
    this.graceUntil,
  });

  factory Subscriber.fromJson(Map<String, dynamic> json) => Subscriber(
        msisdn: json['msisdn'] as String,
        pulsaBalance: json['pulsa_balance'] as int,
        status: json['status'] as String,
        activeUntil: parseDate(json['active_until'] as String),
        daysLeft: json['days_left'] as int,
        graceUntil: json['grace_until'] == null ? null : parseDate(json['grace_until'] as String),
      );

  final String msisdn;
  final int pulsaBalance;

  /// active | grace
  final String status;
  final DateTime activeUntil;
  final int daysLeft;
  final DateTime? graceUntil;

  bool get inGrace => status == 'grace';
}
