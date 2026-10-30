import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/transaction.dart';
import '../providers.dart';
import 'payment_form.dart';

final _transactionProvider = FutureProvider.autoDispose.family<Transaction, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).get(id),
);

/// S10: detail transaksi (FR-6.2).
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(_transactionProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail transaksi')),
      body: switch (transaction) {
        AsyncData(:final value) => _Detail(value),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(_transactionProvider(transactionId))),
        _ => const SkeletonCardList(),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.transaction);

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final rows = <(String, String)>[
      ('Item', t.itemName),
      ('Harga', formatRupiah(t.grossAmount)),
      if (t.discountAmount > 0) ('Diskon poin', '-${formatRupiah(t.discountAmount)} (${t.pointsUsed} poin)'),
      ('Total bayar', formatRupiah(t.netAmount)),
      ('Metode', paymentMethodLabels[t.paymentMethod] ?? t.paymentMethod),
      ('Dibuat', formatDateTime(t.createdAt)),
      if (t.paidAt != null) ('Dibayar', formatDateTime(t.paidAt!)),
      if (t.isPending && t.expiresAt != null) ('Bayar sebelum', formatDateTime(t.expiresAt!)),
      ('Referensi', t.externalRef),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(alignment: Alignment.centerLeft, child: TransactionStatusChip(t.status)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ))),
                        Flexible(child: SelectableText(value, textAlign: TextAlign.end)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (t.isPending) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.push('/payment/${t.id}'), child: const Text('Lanjutkan bayar')),
        ],
      ],
    );
  }
}
