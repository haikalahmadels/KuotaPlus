import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/mascot.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/transaction.dart';
import '../../share/data/share_repository.dart';
import '../../share/providers.dart';
import '../data/transaction_repository.dart';
import '../providers.dart';
import 'payment_form.dart';

/// S09: tab Pembelian (FR-6) dan Berbagi (FR-14). `?tab=berbagi` membuka tab Berbagi (dari layar selesai berbagi).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sharing = GoRouterState.of(context).uri.queryParameters['tab'] == 'berbagi';

    return DefaultTabController(
      // Key ikut query supaya tab berpindah saat route yang sama dibuka dengan ?tab berbeda.
      key: ValueKey(sharing),
      length: 2,
      initialIndex: sharing ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat'),
          bottom: const TabBar(tabs: [Tab(text: 'Pembelian'), Tab(text: 'Berbagi')]),
        ),
        body: const TabBarView(children: [_PurchaseList(), _ShareList()]),
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
      _ => const SkeletonCardList(),
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

/// Tab Berbagi: riwayat sebagai pengirim (FR-14.13). Kuota yang diterima tampil di beranda.
class _ShareList extends ConsumerWidget {
  const _ShareList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(shareHistoryProvider);

    return switch (history) {
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(shareHistoryProvider.future),
          child: value.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyState(
                      mood: MascotMood.rest,
                      title: 'Belum pernah berbagi kuota',
                      message: 'Bagi kuota utama ke teman atau keluarga yang memakai Nusantel.',
                      actionLabel: 'Bagi kuota',
                      onAction: () => context.push('/share'),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: value.items.length + (value.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == value.items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: () => ref.read(shareHistoryProvider.notifier).loadMore(),
                          child: const Text('Muat lagi'),
                        ),
                      );
                    }
                    return _ShareTile(value.items[index]);
                  },
                ),
        ),
      AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(shareHistoryProvider)),
      _ => const SkeletonCardList(),
    };
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile(this.transfer);

  final QuotaTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    final completed = t.status == 'completed';

    return ListTile(
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: AppColors.violetContainer, shape: BoxShape.circle),
        child: const Icon(Icons.ios_share_rounded, color: AppColors.violet, size: 20),
      ),
      title: Text('${formatGb(t.bytes)} ke ${t.recipientMasked}'),
      subtitle: Text(
        '${formatDateTime(t.completedAt ?? t.recipientExpiresAt)} · ${t.pointsSpent} poin\n'
        'Berlaku di penerima s.d. ${formatDateTime(t.recipientExpiresAt)}',
      ),
      isThreeLine: true,
      trailing: StatusChip(
        label: completed ? 'Berhasil' : 'Gagal',
        color: completed ? AppColors.success : AppColors.danger,
      ),
    );
  }
}
