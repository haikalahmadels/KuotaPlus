import 'package:flutter/material.dart';

import '../core/api_exception.dart';

/// Pesan error yang aman ditampilkan ke pengguna.
String errorMessage(Object error) =>
    error is ApiException ? error.message : 'Terjadi kesalahan. Coba lagi.';

/// State error standar: pesan + tombol "Coba lagi" (docs/UI-KuotaPlus.md, prinsip 3).
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage(error), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// Label status berbingkai. Warna selalu disertai teks, tidak pernah sendirian (docs/UI-KuotaPlus.md).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
    );
  }
}
