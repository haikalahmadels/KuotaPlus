import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/transaction.dart';
import '../data/transaction_repository.dart';
import '../providers.dart';
import 'payment_form.dart';

/// S09: tab Pembelian (FR-6) dan Berbagi (FR-14, M8).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat'),
          bottom: const TabBar(tabs: [Tab(text: 'Pembelian'), Tab(text: 'Berbagi')]),
        ),
        body: TabBarView(
          children: [
            const _PurchaseList(),
            Center(
              child: Text('Fitur ini sedang disiapkan.', style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseList extends ConsumerWidget {
  const _PurchaseList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(transactionHistoryProvider);

    return switch (history) {
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(transactionHistoryProvider.future),
          child: _list(context, ref, value),
        ),
      AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(transactionHistoryProvider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _list(BuildContext context, WidgetRef ref, TransactionPage page) {
    if (page.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Text('Belum ada transaksi.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: page.items.length + (page.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == page.items.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () => ref.read(transactionHistoryProvider.notifier).loadMore(),
              child: const Text('Muat lagi'),
            ),
          );
        }
        return _TransactionTile(page.items[index]);
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;

    return ListTile(
      onTap: () => context.push('/history/${t.id}'),
      minVerticalPadding: 12,
      title: Text(t.itemName),
      subtitle: Text('${formatDateTime(t.createdAt)} · ${paymentMethodLabels[t.paymentMethod]}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatRupiah(t.netAmount), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          TransactionStatusChip(t.status),
        ],
      ),
    );
  }
}
