/// Objek `Transaction` (docs/API-KuotaPlus.md). [payment] dan [subscriptionId] hanya ada di detail.
class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.itemName,
    required this.grossAmount,
    required this.discountAmount,
    required this.pointsUsed,
    required this.netAmount,
    required this.paymentMethod,
    required this.status,
    required this.externalRef,
    required this.createdAt,
    this.expiresAt,
    this.paidAt,
    this.payment,
    this.subscriptionId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null ? null : DateTime.parse(json[key] as String);
    final payment = json['payment'] as Map<String, dynamic>?;

    return Transaction(
      id: json['id'] as int,
      type: json['type'] as String,
      itemName: json['item_name'] as String,
      grossAmount: json['gross_amount'] as int,
      discountAmount: json['discount_amount'] as int,
      pointsUsed: json['points_used'] as int,
      netAmount: json['net_amount'] as int,
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      externalRef: json['external_ref'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: date('expires_at'),
      paidAt: date('paid_at'),
      payment: payment == null ? null : PaymentInstructions.fromJson(payment),
      subscriptionId: json['subscription_id'] as int?,
    );
  }

  final int id;

  /// package | topup
  final String type;
  final String itemName;
  final int grossAmount;
  final int discountAmount;
  final int pointsUsed;
  final int netAmount;

  /// pulsa | ewallet | va | qris
  final String paymentMethod;

  /// pending | paid | failed | expired
  final String status;
  final String externalRef;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final PaymentInstructions? payment;
  final int? subscriptionId;

  bool get isPending => status == 'pending';
}

class PaymentInstructions {
  const PaymentInstructions({required this.simulatorUrl, this.vaNumber, this.bankLabel, this.qrString});

  factory PaymentInstructions.fromJson(Map<String, dynamic> json) => PaymentInstructions(
        simulatorUrl: json['simulator_url'] as String,
        vaNumber: json['va_number'] as String?,
        bankLabel: json['bank_label'] as String?,
        qrString: json['qr_string'] as String?,
      );

  final String simulatorUrl;
  final String? vaNumber;
  final String? bankLabel;
  final String? qrString;
}

/// Label generik, tanpa merek asli (OQ-5).
const paymentMethodLabels = {
  'pulsa': 'Pulsa',
  'ewallet': 'E-Wallet',
  'va': 'Virtual Account',
  'qris': 'QRIS',
};

const transactionStatusLabels = {
  'pending': 'Menunggu bayar',
  'paid': 'Berhasil',
  'failed': 'Gagal',
  'expired': 'Kedaluwarsa',
};
