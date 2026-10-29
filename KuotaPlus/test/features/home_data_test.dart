import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/core/format.dart';
import 'package:kuota_plus/features/home/data/home_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('respons GET /home dari backend terbaca utuh', () {
    // Potongan respons nyata akun Uji HP setelah migrate:fresh --seed.
    final data = HomeData.fromJson({
      'server_time': '2026-10-29T16:30:00+07:00',
      'subscriber': {
        'msisdn': '6288100000004',
        'pulsa_balance': 100000,
        'status': 'active',
        'active_until': '2026-12-28',
        'days_left': 60,
        'grace_until': null,
      },
      'subscriptions': [
        {
          'id': 1,
          'source': 'purchase',
          'name': 'Bulanan 25 GB',
          'main_total': 26843545600,
          'main_used': 0,
          'main_remaining': 26843545600,
          'app_total': 0,
          'app_used': 0,
          'app_remaining': 0,
          'app_category': null,
          'started_at': '2026-10-29T07:00:00+07:00',
          'expires_at': '2026-11-28T07:00:00+07:00',
          'status': 'active',
          'shared_from': null,
        },
      ],
      'forecast': null,
      'points': {'balance': 0, 'streak': 0},
      'alerts': [],
    });

    expect(data.subscriber.pulsaBalance, 100000);
    expect(data.subscriber.inGrace, isFalse);
    expect(formatDate(data.subscriber.activeUntil), '28 Des 2026');
    expect(data.subscriptions.single.name, 'Bulanan 25 GB');
    expect(formatBytes(data.subscriptions.single.mainRemaining), '25 GB');
    expect(formatDateTime(data.subscriptions.single.expiresAt), '28 Nov 2026, 07.00');
  });

  test('tanggal tanpa jam tetap di hari yang sama apa pun zona waktunya', () {
    expect(formatDate(parseDate('2026-11-23')), '23 Nov 2026');
  });
}
