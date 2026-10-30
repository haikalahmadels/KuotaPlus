import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/features/auth/data/auth_repository.dart';
import 'package:kuota_plus/features/share/data/share_repository.dart';
import 'package:kuota_plus/features/share/providers.dart';
import 'package:kuota_plus/features/share/ui/share_screen.dart';

const _half = 536870912;

/// Contoh respons GET /quota-transfers/quote (docs/API-KuotaPlus.md) dengan jatah tersisa 1,5 GB.
final _quoteJson = {
  'recipient': {'msisdn_masked': '0881••••0007', 'has_account': true},
  'allowance': {
    'limit_bytes': 4 * _half,
    'used_30d_bytes': _half,
    'remaining_bytes': 3 * _half,
    'recovers_at': '2026-11-15',
  },
  'sender_main_remaining_bytes': 10737418240,
  'points_balance': 340,
  'options': [
    for (var i = 1; i <= 3; i++)
      {
        'bytes': i * _half,
        'points_cost': i * 100,
        'allowed': true,
        'reason': null,
        'recipient_expires_at': '2026-11-05T14:05:00+07:00',
        'sender_main_remaining_after': 10737418240 - i * _half,
      },
    {'bytes': 4 * _half, 'points_cost': 400, 'allowed': false, 'reason': 'Melebihi sisa jatah berbagi 1,5 GB.'},
  ],
};

class _FakeShareRepository implements ShareRepository {
  final requested = <String>[];

  @override
  Future<ShareQuote> quote(String recipientMsisdn) async {
    requested.add(recipientMsisdn);
    return ShareQuote.fromJson(_quoteJson);
  }

  @override
  Future<OtpChallenge> requestOtp(String recipientMsisdn, int bytes) => throw UnimplementedError();

  @override
  Future<QuotaTransfer> execute({
    required String recipientMsisdn,
    required int bytes,
    required String otpCode,
    required String idempotencyKey,
  }) =>
      throw UnimplementedError();

  @override
  Future<QuotaTransferPage> list({int page = 1}) => throw UnimplementedError();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('quote terbaca: opsi yang ditolak tetap ada beserta alasannya', () {
    final quote = ShareQuote.fromJson(_quoteJson);

    expect(quote.recipientMasked, '0881••••0007');
    expect(quote.remainingBytes, 3 * _half);
    expect(quote.options.map((o) => o.allowed), [true, true, true, false]);
    expect(quote.options.last.reason, contains('jatah berbagi'));
    expect(quote.options.last.recipientExpiresAt, isNull);
  });

  testWidgets('nomor → pilihan jumlah → ringkasan; pilihan nonaktif tidak bisa dipilih', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeShareRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [shareRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: ShareScreen()),
    ));

    await tester.enterText(find.byType(TextField), '0881-0000-0007');
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(repo.requested, ['0881-0000-0007']);
    expect(find.text('0,5 GB'), findsOneWidget);
    expect(find.text('Melebihi sisa jatah berbagi 1,5 GB.'), findsOneWidget);
    expect(find.text('Ringkasan'), findsNothing);

    // 2 GB ditolak: mengetuknya tidak memilih apa pun.
    await tester.tap(find.text('2 GB'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan'), findsNothing);

    await tester.tap(find.text('1 GB'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan'), findsOneWidget);
    expect(find.text('200 dari 340 poin'), findsOneWidget);
    expect(find.text('9 GB'), findsOneWidget); // sisa kuota utama setelah berbagi
  });
}
