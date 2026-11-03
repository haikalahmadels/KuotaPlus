import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/core/format.dart';
import 'package:kuota_plus/core/models/quota_package.dart';
import 'package:kuota_plus/core/models/transaction.dart';
import 'package:kuota_plus/features/packages/data/catalog_repository.dart';
import 'package:kuota_plus/features/packages/providers.dart';
import 'package:kuota_plus/features/packages/ui/checkout_screen.dart';
import 'package:kuota_plus/features/recommendations/data/recommendation_repository.dart';
import 'package:kuota_plus/features/recommendations/providers.dart';
import 'package:kuota_plus/features/recommendations/ui/recommendations_screen.dart';
import 'package:kuota_plus/features/transactions/data/transaction_repository.dart';
import 'package:kuota_plus/features/transactions/providers.dart';
import 'package:kuota_plus/features/transactions/ui/history_screen.dart';

const _gb = 1024 * 1024 * 1024;

Transaction _tx(int id, String status, DateTime created, {int net = 25000, int discount = 0, String type = 'package'}) =>
    Transaction(
      id: id,
      type: type,
      itemName: 'Paket $id',
      grossAmount: net + discount,
      discountAmount: discount,
      pointsUsed: discount ~/ 10,
      netAmount: net,
      paymentMethod: 'qris',
      status: status,
      externalRef: 'KP-$id',
      createdAt: created,
      expiresAt: status == 'pending' ? DateTime.now().add(const Duration(minutes: 14)) : null,
      paidAt: status == 'paid' ? created : null,
    );

class _FakeTransactions implements TransactionRepository {
  _FakeTransactions(this.items);

  final List<Transaction> items;

  @override
  Future<TransactionPage> list({int page = 1}) async => TransactionPage(items, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeRecommendations implements RecommendationRepository {
  @override
  Future<Recommendations> current() async => Recommendations.fromJson({
        'status': 'ok',
        'need': {'total_bytes': 24 * _gb},
        'spent_30d': 85000,
        'items': [
          _item(1, 1, 'Video 30 Hari', 65000, 12, 16, 4),
          _item(2, 2, 'Bulanan 25 GB', 85000, 25, 0, 1),
        ],
      });

  @override
  Future<void> click(int id) async {}
}

Map<String, dynamic> _item(int id, int rank, String name, int price, int main, int app, int leftover) => {
      'id': id,
      'rank': rank,
      'package': _package(id, name, price, main, app),
      'cost_30d': price,
      'saving_30d': 85000 - price,
      'leftover_bytes': leftover * _gb,
      'reason': 'Alasan $name.',
    };

Map<String, dynamic> _package(int id, String name, int price, int main, int app) => {
      'id': id,
      'code': 'P$id',
      'name': name,
      'type': 'bulanan',
      'price': price,
      'main_quota': main * _gb,
      'app_quota': app * _gb,
      'app_category': app > 0 ? 'video' : null,
      'app_examples': app > 0 ? ['YouTube'] : <String>[],
      'validity_days': 30,
      'is_recommended': false,
    };

Widget _app(Widget child, List overrides) => ProviderScope(
      overrides: [...overrides],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => child)]),
        ),
      ),
    );

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('label hari riwayat mengikuti WIB', () {
    final now = DateTime.parse('2026-11-03T10:00:00+07:00');
    expect(formatDayLabel(DateTime.parse('2026-11-03T00:30:00+07:00'), now), 'Hari ini');
    // 23.30 UTC tanggal 2 = 06.30 WIB tanggal 3.
    expect(formatDayLabel(DateTime.parse('2026-11-02T23:30:00Z'), now), 'Hari ini');
    expect(formatDayLabel(DateTime.parse('2026-11-02T21:40:00+07:00'), now), 'Kemarin');
    expect(formatDayLabel(DateTime.parse('2026-10-28T16:20:00+07:00'), now), 'Rabu, 28 Okt');
  });

  testWidgets('riwayat: kartu belum dibayar, ringkasan bulan, filter, label status hanya untuk yang perlu perhatian',
      (tester) async {
    _tallView(tester);
    final now = DateTime.now();
    final repo = _FakeTransactions([
      _tx(1, 'pending', now, net: 60000, discount: 5000),
      _tx(2, 'paid', now, net: 25000, discount: 5000, type: 'topup'),
      _tx(3, 'failed', now, net: 65000),
    ]);

    await tester.pumpWidget(_app(const HistoryScreen(), [transactionRepositoryProvider.overrideWithValue(repo)]));
    await tester.pumpAndSettle();

    expect(find.text('Belum dibayar'), findsOneWidget);
    expect(find.textContaining('Belanja '), findsOneWidget);
    expect(find.text('Rp25.000'), findsWidgets);
    expect(find.text('Berhasil'), findsOneWidget); // hanya chip filter; baris berhasil tanpa label
    expect(find.text('Gagal'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Gagal, 1'));
    await tester.pumpAndSettle();
    expect(find.text('Paket 3'), findsOneWidget);
    expect(find.text('Paket 2'), findsNothing);

    await tester.tap(find.text('Paket 3'));
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran tidak berhasil'), findsOneWidget);
    expect(find.text('Beli lagi'), findsOneWidget);
  });

  testWidgets('checkout: memakai poin memperbarui label tombol bayar', (tester) async {
    _tallView(tester);
    final package = QuotaPackage.fromJson(_package(1, 'Video 30 Hari', 65000, 12, 16));
    const rules = PointRules(balance: 520, rupiahPerPoint: 10, redeemStep: 100, maxDiscountPercent: 20, minNetAmount: 1000);

    await tester.pumpWidget(_app(CheckoutScreen(package: package), [
      packagesProvider.overrideWith((ref) async => const Catalog([], rules)),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Bayar Rp65.000'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    // Maks 20% dari 65.000 = 13.000 → 1.300 poin, dibatasi saldo 520 → 500 poin = Rp5.000.
    expect(find.text('Bayar Rp60.000'), findsOneWidget);
    await tester.tap(find.text('100 poin'));
    await tester.pumpAndSettle();
    expect(find.text('Bayar Rp64.000'), findsOneWidget);
  });

  testWidgets('rekomendasi: perbandingan belanja dan alternatif dengan selisih', (tester) async {
    _tallView(tester);

    await tester.pumpWidget(_app(const RecommendationsScreen(), [
      recommendationRepositoryProvider.overrideWithValue(_FakeRecommendations()),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Video 30 Hari'), findsOneWidget);
    expect(find.text('Hemat Rp20.000/bulan'), findsOneWidget);
    expect(find.text('Cukup, masih sisa ±4 GB'), findsOneWidget);
    expect(find.text('+Rp20.000'), findsOneWidget);
    expect(find.text('Alasan Video 30 Hari.'), findsNothing);

    await tester.tap(find.text('Kenapa paket ini?'));
    await tester.pumpAndSettle();
    expect(find.text('Alasan Video 30 Hari.'), findsOneWidget);
  });
}
