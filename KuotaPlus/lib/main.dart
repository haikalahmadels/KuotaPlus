import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/api_client.dart';
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

class KuotaPlusApp extends ConsumerWidget {
  const KuotaPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kuota+',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
