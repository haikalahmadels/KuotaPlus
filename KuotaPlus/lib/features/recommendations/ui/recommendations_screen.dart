import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/api_client.dart';
import '../../../core/format.dart';
import '../data/recommendation_repository.dart';

final recommendationRepositoryProvider = Provider((ref) => RecommendationRepository(ref.watch(apiClientProvider)));

final recommendationsProvider =
    FutureProvider.autoDispose((ref) => ref.watch(recommendationRepositoryProvider).current());

/// S14: rekomendasi paket hemat (FR-10, US-09, US-10).
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(recommendationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rekomendasi paket')),
      body: switch (recommendations) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(recommendationsProvider.future),
            child: _Content(value),
          ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(recommendationsProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content(this.recommendations);

  final Recommendations recommendations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final r = recommendations;

    if (r.status == 'insufficient_data') {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text('Rekomendasi tersedia setelah 7 hari pemakaian', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Kuota+ butuh pola pemakaian seminggu penuh supaya paket yang disarankan benar-benar cukup.', style: muted),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (r.needBytes != null)
          Text('Perkiraan kebutuhanmu ${formatBytes(r.needBytes!)} per 30 hari (sudah termasuk cadangan 10%).', style: muted),
        if (r.status == 'already_cheapest') ...[
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: AppColors.success),
              title: Text('Paketmu sekarang sudah paling hemat'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (r.items.isEmpty)
          Text('Belum ada paket di katalog yang cukup untuk pemakaianmu.', style: muted)
        else
          for (final item in r.items) ...[
            _ItemCard(item),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard(this.item);

  final RecommendationItem item;

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    ref.read(recommendationRepositoryProvider).click(item.id);
    await context.push('/packages/${item.package.id}/checkout', extra: (item.package, item.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final saving = item.saving30d;
    final isTop = item.rank == 1;

    return Card(
      shape: isTop
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isTop ? 'Paling hemat untukmu' : 'Alternatif ${item.rank - 1}',
                style: theme.textTheme.labelLarge?.copyWith(color: isTop ? AppColors.primary : null)),
            const SizedBox(height: 4),
            Text(item.package.name, style: theme.textTheme.titleLarge),
            Text('${formatRupiah(item.cost30d)} per 30 hari', style: theme.textTheme.bodyLarge),
            if (saving != null) ...[
              const SizedBox(height: 8),
              if (saving > 0)
                StatusChip(label: 'Hemat ${formatRupiah(saving)}/bulan', color: AppColors.success)
              else if (saving == 0)
                Text('Sama dengan belanja paketmu 30 hari terakhir.', style: muted)
              else
                // Paket sekarang tidak cukup; rekomendasi cukup sebulan penuh walau sedikit lebih mahal.
                Text('${formatRupiah(-saving)} lebih mahal dari belanja paketmu 30 hari terakhir, tapi cukup sebulan penuh.',
                    style: muted),
            ],
            const SizedBox(height: 8),
            Text(item.reason, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: isTop
                  ? FilledButton(onPressed: () => _buy(context, ref), child: const Text('Beli paket ini'))
                  : OutlinedButton(onPressed: () => _buy(context, ref), child: const Text('Beli')),
            ),
          ],
        ),
      ),
    );
  }
}
