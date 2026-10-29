import 'package:flutter_test/flutter_test.dart';
import 'package:kuota_plus/core/models/transaction.dart';

void main() {
  test('detail transaksi QRIS pending dari backend terbaca utuh', () {
    // Bentuk respons nyata POST /transactions (uji smoke lewat Apache).
    final t = Transaction.fromJson({
      'id': 1,
      'type': 'package',
      'item_name': 'Bulanan 15 GB',
      'package_id': 6,
      'topup_amount': null,
      'gross_amount': 55000,
      'discount_amount': 0,
      'points_used': 0,
      'net_amount': 55000,
      'payment_method': 'qris',
      'status': 'pending',
      'external_ref': 'KP-20261029-KRS4V2',
      'expires_at': '2026-10-29T17:05:00+07:00',
      'paid_at': null,
      'created_at': '2026-10-29T16:50:00+07:00',
      'payment': {
        'va_number': null,
        'bank_label': null,
        'qr_string': 'NUSANTEL-QRIS|KP-20261029-KRS4V2|55000',
        'simulator_url': 'http://192.168.1.32/simulator/KP-20261029-KRS4V2',
      },
      'subscription_id': null,
    });

    expect(t.isPending, isTrue);
    expect(t.payment!.qrString, 'NUSANTEL-QRIS|KP-20261029-KRS4V2|55000');
    expect(t.payment!.vaNumber, isNull);
    expect(t.expiresAt!.difference(t.createdAt), const Duration(minutes: 15));
  });

  test('item riwayat tanpa objek payment dan pulsa tanpa instruksi', () {
    final t = Transaction.fromJson({
      'id': 2,
      'type': 'topup',
      'item_name': 'Isi ulang Rp25.000',
      'gross_amount': 25000,
      'discount_amount': 0,
      'points_used': 0,
      'net_amount': 25000,
      'payment_method': 'va',
      'status': 'paid',
      'external_ref': 'KP-20261029-ABCDEF',
      'expires_at': '2026-10-29T17:05:00+07:00',
      'paid_at': '2026-10-29T16:52:00+07:00',
      'created_at': '2026-10-29T16:50:00+07:00',
    });

    expect(t.payment, isNull);
    expect(t.subscriptionId, isNull);
    expect(transactionStatusLabels[t.status], 'Berhasil');
  });
}
