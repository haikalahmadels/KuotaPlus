import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/api_client.dart';
import 'core/notifications.dart';
import 'core/session.dart';
import 'core/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  // Token dibaca sebelum frame pertama supaya tidak ada kedipan layar login saat sudah masuk.
  final tokens = TokenStorage();
  final signedIn = await tokens.read() != null;

  runApp(ProviderScope(
    // Tanpa retry otomatis: error langsung tampil dengan tombol "Coba lagi", dan cache offline beranda langsung dipakai.
    retry: (retryCount, error) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      initialSignedInProvider.overrideWithValue(signedIn),
    ],
    child: const KuotaPlusApp(),
  ));
}

class KuotaPlusApp extends ConsumerStatefulWidget {
  const KuotaPlusApp({super.key});

  @override
  ConsumerState<KuotaPlusApp> createState() => _KuotaPlusAppState();
}

class _KuotaPlusAppState extends ConsumerState<KuotaPlusApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  /// FR-13.3: notifikasi yang diketuk membuka `target`, baik saat aplikasi berjalan maupun saat membukanya.
  Future<void> _initNotifications() async {
    void open(String target) => openAlertTarget(ref.read(routerProvider), target);

    await AlertNotifications.init(onTap: open);
    final launched = await AlertNotifications.launchTarget();
    if (launched != null && mounted) WidgetsBinding.instance.addPostFrameCallback((_) => open(launched));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kuota+',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
