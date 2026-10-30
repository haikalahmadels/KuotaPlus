import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models/alert.dart';
import 'platform.dart';

/// Notifikasi lokal Android untuk alert FR-13 (docs/TECH-KuotaPlus.md, Notifikasi dan deep link).
/// Dipakai juga oleh WorkManager di engine latar belakang, jadi tanpa Riverpod. Di web semua fungsi diam:
/// alert web tampil sebagai banner di beranda.
abstract final class AlertNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kuotaplus_alerts',
      'Peringatan kuota',
      channelDescription: 'Kuota menipis, paket atau masa aktif segera berakhir, dan status pembayaran.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// [onTap] menerima `target` saat notifikasi diketuk ketika aplikasi berjalan.
  static Future<void> init({void Function(String target)? onTap}) async {
    if (!isAndroidApp || _ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final target = response.payload;
        if (target != null && target.isNotEmpty) onTap?.call(target);
      },
    );
    _ready = true;
  }

  /// Target notifikasi yang membuka aplikasi dari keadaan tertutup, jika ada.
  static Future<String?> launchTarget() async {
    if (!isAndroidApp) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Android 13+: meminta izin notifikasi (dialog sistem hanya muncul sekali).
  static Future<void> requestPermission() async {
    if (!isAndroidApp) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show(List<Alert> alerts) async {
    if (!isAndroidApp || alerts.isEmpty) return;
    await init();
    for (final alert in alerts) {
      // id alert dari server unik, jadi notifikasi yang sama tidak menumpuk dua kali.
      await _plugin.show(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        notificationDetails: _details,
        payload: alert.target,
      );
    }
  }
}
