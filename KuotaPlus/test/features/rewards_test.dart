import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/app/theme.dart';
import 'package:kuota_plus/features/packages/data/catalog_repository.dart';
import 'package:kuota_plus/features/rewards/data/rewards_repository.dart';
import 'package:kuota_plus/features/rewards/providers.dart';
import 'package:kuota_plus/features/rewards/ui/rewards_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Respons nyata GET /points akun Rina setelah migrate:fresh --seed.
  final points = PointsSummary.fromJson(
    jsonDecode(File('test/fixtures/points_rina.json').readAsStringSync()) as Map<String, dynamic>,
  );

  PointRules rules(int balance) => PointRules(
        balance: balance,
        rupiahPerPoint: 10,
        redeemStep: 100,
        maxDiscountPercent: 20,
        minNetAmount: 1000,
      );

  test('batas tukar poin sama dengan aturan server (FR-12)', () {
    expect(rules(520).maxPointsFor(65000), 500, reason: 'dibatasi saldo, kelipatan 100');
    expect(rules(5000).maxPointsFor(65000), 1300, reason: '20% × Rp65.000');
    expect(rules(5000).maxPointsFor(5000), 100, reason: 'HR1: 20% = Rp1.000');
    expect(rules(5000).maxPointsFor(1000), 0, reason: 'total bayar minimal Rp1.000');
    expect(rules(99).maxPointsFor(65000), 0);
  });

  test('ringkasan poin Rina terbaca utuh', () {
    expect(points.balance, 520);
    expect(points.streak, 0);
    expect(points.calendar, hasLength(30));
    expect(points.expiringPoints, isNotNull);
  });

  testWidgets('layar Reward menampilkan saldo, kalender, dan legenda', (tester) async {
    // Layar HP tinggi supaya seluruh isi ListView dirender.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [pointsProvider.overrideWith((ref) async => points)],
      child: MaterialApp(theme: buildTheme(), home: const RewardsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('520'), findsOneWidget);
    expect(find.text('Tidak ada data'), findsOneWidget);
    expect(find.textContaining('poin kedaluwarsa mulai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
