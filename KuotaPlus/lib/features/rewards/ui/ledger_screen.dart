import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../providers.dart';

/// S16: riwayat poin masuk dan keluar (FR-11.7, US-16).
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat poin')),
      body: switch (ledger) {
        AsyncData(:final value) when value.items.isEmpty =>
          const Center(child: Text('Belum ada poin. Hemat sehari untuk mendapat poin pertama.')),
        AsyncData(:final value) => ListView.separated(
            itemCount: value.items.length + (value.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == value.items.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: () => ref.read(ledgerProvider.notifier).loadMore(),
                    child: const Text('Muat lagi'),
                  ),
                );
              }
              final entry = value.items[index];
              final positive = entry.delta > 0;
              return ListTile(
                title: Text(entry.description),
                subtitle: Text(formatDateTime(entry.createdAt)),
                trailing: Text(
                  '${positive ? '+' : ''}${entry.delta}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: positive ? AppColors.success : AppColors.text,
                      ),
                ),
              );
            },
          ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(ledgerProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
