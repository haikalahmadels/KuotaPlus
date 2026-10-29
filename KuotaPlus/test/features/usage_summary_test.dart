import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/app/theme.dart';
import 'package:kuota_plus/features/usage/data/usage_repository.dart';
import 'package:kuota_plus/features/usage/ui/usage_charts.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Respons nyata GET /usage/summary?period=7d akun Rina setelah Mode Demo profil rina.
  final summary = UsageSummary.fromJson(
    jsonDecode(File('test/fixtures/usage_summary_7d.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('respons analisis terbaca utuh', () {
    expect(summary.hasData, isTrue);
    expect(summary.source, 'demo');
    expect(summary.daily, hasLength(7));
    expect(summary.topApps.first.label, 'TikTok');
    expect(summary.topApps.last.appId, isNull, reason: 'baris "Lainnya"');
    expect(summary.insights.single, startsWith('TikTok memakai'));
  });

  test('warna donut: gradasi menurut peringkat, Lainnya abu-abu', () {
    expect(usageColor(summary.topApps.first, 0), rankColors.first);
    expect(usageColor(summary.topApps.last, summary.topApps.length - 1), othersColor);
  });

  testWidgets('chart donut dan harian dirender tanpa error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: ListView(children: [
          UsageDonut(apps: summary.topApps, totalBytes: summary.totalBytes),
          DailyUsageChart(daily: summary.daily),
        ]),
      ),
    ));

    expect(find.text('4,9 GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
