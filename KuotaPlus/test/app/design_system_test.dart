import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuota_plus/app/mascot.dart';
import 'package:kuota_plus/app/theme.dart';

Future<void> _loadFont() async {
  final loader = FontLoader(fontFamily);
  for (final weight in ['Regular', 'Bold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

double _width(String text, TextStyle style) =>
    (TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout()).width;

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  test('angka utama Plus Jakarta Sans tabular: lebar "111" sama dengan "888"', () async {
    await _loadFont();

    expect(_width('111', displayNumber), _width('888', displayNumber));
    // Tanpa fitur tabular angkanya proporsional, jadi tes di atas memang menguji fiturnya.
    final proportional = displayNumber.copyWith(fontFeatures: const []);
    expect(_width('111', proportional), lessThan(_width('888', proportional)));
  });

  test('tint chip berpasangan dengan warna status, warna lain jadi netral', () {
    expect(AppColors.containerOf(AppColors.warning), AppColors.warningContainer);
    expect(AppColors.containerOf(AppColors.danger), AppColors.dangerContainer);
    expect(AppColors.containerOf(AppColors.textMuted), AppColors.neutralContainer);
  });

  testWidgets('maskot diam total saat "kurangi animasi" aktif', (tester) async {
    for (final mood in MascotMood.values) {
      await tester.pumpWidget(_app(Mascot(mood: mood), reduceMotion: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: '$mood masih beranimasi');
    }
  });

  testWidgets('perayaan maskot berjalan sekali lalu berhenti, dan maskot tidak dibacakan', (tester) async {
    await tester.pumpWidget(_app(const Mascot(mood: MascotMood.celebrate)));
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.descendant(of: find.byType(Mascot), matching: find.byType(ExcludeSemantics)), findsOneWidget);
  });
}
