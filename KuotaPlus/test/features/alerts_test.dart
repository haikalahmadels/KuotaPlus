import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuota_plus/core/models/alert.dart';
import 'package:kuota_plus/core/session.dart';
import 'package:kuota_plus/features/home/data/home_repository.dart';
import 'package:kuota_plus/features/home/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Alert _alert(int id, [String kind = 'quota_low']) => Alert(
      id: id,
      kind: kind,
      title: 'Judul $id',
      body: 'Isi $id',
      target: '/recommendations',
      createdAt: DateTime(2026, 10, 30),
    );

void main() {
  test('alert di GET /home terbaca, dan cache lama tanpa field alerts tetap terbaca', () {
    final json = jsonDecode(File('test/fixtures/home_budi.json').readAsStringSync()) as Map<String, dynamic>;
    expect(HomeData.fromJson(json).alerts, isEmpty);

    json['alerts'] = [
      {
        'id': 310,
        'kind': 'transaction_status',
        'title': 'Pembayaran berhasil',
        'body': 'Bulanan 15 GB sudah aktif dan bisa langsung dipakai.',
        'target': '/history/42',
        'created_at': '2026-10-30T09:15:00+07:00',
      },
    ];
    final alert = HomeData.fromJson(json).alerts.single;
    expect(alert.kind, 'transaction_status');
    expect(alert.target, '/history/42');

    json.remove('alerts');
    expect(HomeData.fromJson(json).alerts, isEmpty);
  });

  test('banner web: alert yang sama tidak dobel, bisa ditutup, dan kosong setelah keluar akun', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [initialSignedInProvider.overrideWithValue(true)]);
    addTearDown(container.dispose);
    final inbox = container.read(alertInboxProvider.notifier);

    inbox.add([_alert(1), _alert(2, 'card_expiring')]);
    inbox.add([_alert(2, 'card_expiring'), _alert(3)]);
    expect(container.read(alertInboxProvider).map((a) => a.id), [1, 2, 3]);

    inbox.dismiss(2);
    expect(container.read(alertInboxProvider).map((a) => a.id), [1, 3]);

    container.read(authProvider.notifier).signedOut();
    expect(container.read(alertInboxProvider), isEmpty);
  });
}
