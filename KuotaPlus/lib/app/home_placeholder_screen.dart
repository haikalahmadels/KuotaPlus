import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers.dart';

/// Layar sementara M1, diganti beranda (S04) di M2.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).logout(),
            child: const Text('Keluar'),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Kamu sudah masuk. Beranda lengkap dibuat di M2.'),
      ),
    );
  }
}
