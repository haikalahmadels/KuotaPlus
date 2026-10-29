import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';

/// Layar sementara M0: membuktikan aplikasi bisa menjangkau backend. Diganti layar login di M1.
class ServerCheckScreen extends ConsumerStatefulWidget {
  const ServerCheckScreen({super.key});

  @override
  ConsumerState<ServerCheckScreen> createState() => _ServerCheckScreenState();
}

class _ServerCheckScreenState extends ConsumerState<ServerCheckScreen> {
  String _result = 'Memeriksa…';
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _result = 'Memeriksa…');
    try {
      await ref.read(apiClientProvider).get('/home');
      _show(true, 'Server terjangkau.');
    } on ApiException catch (e) {
      // Respons JSON apa pun (404/401) berarti server terjangkau; hanya error jaringan yang gagal.
      _show(!e.isNetwork, e.isNetwork ? e.message : 'Server terjangkau (${e.code}).');
    }
  }

  void _show(bool ok, String result) {
    if (!mounted) return;
    setState(() {
      _ok = ok;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _ok ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Kuota+')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('API_BASE_URL', style: Theme.of(context).textTheme.bodySmall),
            Text(apiBaseUrl, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text(_result, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _check, child: const Text('Cek lagi')),
          ],
        ),
      ),
    );
  }
}
