import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuota_plus/features/usage/ui/app_logo.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('web/demo: logo resmi dibundel, aplikasi lain huruf awal, Lainnya ikon', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(_wrap(const AppLogo(packageName: 'com.whatsapp', label: 'WhatsApp')));
    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pumpWidget(_wrap(const AppLogo(packageName: 'com.shopee.id', label: 'Shopee')));
    expect(find.text('S'), findsOneWidget);

    await tester.pumpWidget(_wrap(const AppLogo(packageName: null, label: 'Lainnya')));
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android: ikon dari HP dipakai; aplikasi tidak terpasang jatuh ke logo dibundel', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // PNG 1×1 transparan sebagai "ikon dari PackageManager".
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kuotaplus/usage_stats'), (call) async {
      // Hanya Instagram yang "terpasang".
      return call.arguments['packageName'] == 'com.instagram.android' ? png : null;
    });

    await tester.pumpWidget(_wrap(const AppLogo(packageName: 'com.instagram.android', label: 'Instagram')));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(_wrap(const AppLogo(packageName: 'us.zoom.videomeetings', label: 'Zoom')));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kuotaplus/usage_stats'), null);
    debugDefaultTargetPlatformOverride = null;
  });
}
