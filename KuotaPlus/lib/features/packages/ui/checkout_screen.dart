import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../../transactions/providers.dart';
import '../../transactions/ui/payment_form.dart';

/// S06 Checkout paket. Tukar poin ditambahkan di M6 (FR-12).
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key, required this.package});

  final QuotaPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = package;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('${formatBytes(p.mainQuota)} utama · ${p.validityDays} hari', style: theme.textTheme.bodyLarge),
                  if (p.appQuota > 0)
                    Text('+ ${formatBytes(p.appQuota)} ${categoryLabels[p.appCategory] ?? 'aplikasi'}',
                        style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Paket aktif setelah dibayar dan berjalan bersama paket lain. Membeli paket tidak menambah masa aktif nomor.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PaymentForm(
            methods: const ['pulsa', 'ewallet', 'va', 'qris'],
            total: p.price,
            onSubmit: (method, key) => ref.read(transactionRepositoryProvider).create(
                  type: 'package',
                  packageId: p.id,
                  paymentMethod: method,
                  idempotencyKey: key,
                ),
          ),
        ],
      ),
    );
  }
}
