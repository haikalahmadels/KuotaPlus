import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/app/theme.dart';
import 'package:kuota_plus/core/models/forecast.dart';
import 'package:kuota_plus/features/home/data/home_repository.dart';
import 'package:kuota_plus/features/home/ui/forecast_cards.dart';
import 'package:kuota_plus/features/home/ui/home_cards.dart';
import 'package:kuota_plus/features/recommendations/data/recommendation_repository.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

Widget _wrap(Widget child) => MaterialApp(theme: buildTheme(), home: Scaffold(body: child));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Respons nyata akun Budi: BL50 dibeli dengan pulsa + Mode Demo profil budi.
  test('beranda membaca prediksi, jatah harian, dan teaser', () {
    final home = HomeData.fromJson(_fixture('home_budi.json'));

    expect(home.forecast!.status, 'safe');
    expect(home.forecast!.confidence, 'high');
    expect(home.dailyBudget!.budgetBytes, greaterThan(0));
    expect(home.teaser!.packageName, 'Bulanan 15 GB');
    expect(home.teaser!.saving, 80000);
  });

  test('rekomendasi Budi: Bulanan 15 GB, hemat Rp80.000', () {
    final recommendations = Recommendations.fromJson(_fixture('recommendations_budi.json'));

    expect(recommendations.status, 'ok');
    expect(recommendations.items.map((i) => i.package.code), ['BL15', 'VID30', 'BL25']);
    expect(recommendations.items.first.saving30d, 80000);
    expect(recommendations.items.first.reason, contains('WhatsApp dan Google Maps'));
  });

  testWidgets('kartu prediksi Berisiko menyebut tanggal dan selisih hari', (tester) async {
    await tester.pumpWidget(_wrap(ForecastCard(Forecast(
      confidence: 'high',
      status: 'risk',
      remainingBytes: 5 * 1024 * 1024 * 1024,
      mainExpiresAt: DateTime.parse('2026-11-16T07:00:00+07:00'),
      predictedEmptyAt: DateTime.parse('2026-11-05T18:00:00+07:00'),
      daysEarly: 11,
    ))));

    expect(find.text('Berisiko'), findsOneWidget);
    expect(find.text('Kuota diperkirakan habis 5 Nov 2026'), findsOneWidget);
    expect(find.textContaining('11 hari lebih cepat'), findsOneWidget);
  });

  testWidgets('kartu prediksi tanpa data dan kartu jatah yang terlewati', (tester) async {
    await tester.pumpWidget(_wrap(Column(children: [
      ForecastCard(Forecast(confidence: 'none', status: null, remainingBytes: 0, mainExpiresAt: DateTime(2026, 12))),
      const DailyTank(budgetBytes: 500 * 1024 * 1024, usedTodayBytes: 650 * 1024 * 1024),
    ])));

    expect(find.text('Kumpulkan data pemakaian 3 hari dulu.'), findsOneWidget);
    expect(find.text('Terpakai 650 MB, lewat 150 MB dari jatah'), findsOneWidget);
  });
}
