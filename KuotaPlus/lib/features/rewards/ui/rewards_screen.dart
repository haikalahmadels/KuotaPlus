import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../data/rewards_repository.dart';
import '../providers.dart';

/// S15: saldo, streak, kalender 30 hari, poin akan kedaluwarsa (FR-11.7).
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward'),
        actions: [TextButton(onPressed: () => context.push('/rewards/ledger'), child: const Text('Riwayat'))],
      ),
      body: switch (points) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(pointsProvider.future),
            child: _Content(value),
          ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(pointsProvider)),
        _ => const SkeletonCardList(),
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content(this.points);

  final PointsSummary points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = points;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo poin', style: muted),
                      Text('${p.balance}', style: displayNumber),
                      if (p.held > 0) Text('${p.held} poin ditahan transaksi yang belum dibayar', style: muted),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Hari hemat beruntun', style: muted),
                    Text('${p.streak}', style: theme.textTheme.headlineMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (p.expiringPoints != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.hourglass_bottom, color: AppColors.warning),
              title: Text('${p.expiringPoints} poin kedaluwarsa mulai ${formatDate(p.firstExpiresAt!)}'),
              subtitle: const Text('Pakai sebagai diskon saat beli paket.'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('30 hari terakhir', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        _Calendar(p.calendar),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _Legend(result: 'hemat', label: 'Hemat'),
            _Legend(result: 'boros', label: 'Boros'),
            _Legend(result: 'no_data', label: 'Tidak ada data'),
          ],
        ),
        const SizedBox(height: 24),
        Text('Cara dapat poin', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Pakai data di bawah jatah harianmu (minimal ${formatBytes(p.minUsageBytes)}) untuk +${p.pointsPerDay} poin. '
          'Setiap ${p.streakLength} hari hemat berturut-turut dapat bonus +${p.streakBonus} poin. '
          'Poin berlaku 90 hari dan bisa ditukar jadi diskon paket.',
          style: muted,
        ),
      ],
    );
  }
}

/// Status tidak pernah lewat warna saja: setiap sel punya ikon dan label pembaca layar.
const _resultStyles = {
  'hemat': (AppColors.success, Icons.check, 'hemat'),
  'boros': (AppColors.danger, Icons.close, 'boros'),
  'no_data': (AppColors.noData, Icons.remove, 'tidak ada data'),
};

class _Calendar extends StatelessWidget {
  const _Calendar(this.days);

  final List<CalendarDay> days;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final day in days)
          Builder(builder: (context) {
            final (color, icon, label) = _resultStyles[day.result] ?? _resultStyles['no_data']!;
            return Semantics(
              label: '${formatDate(day.date)}: $label${day.points > 0 ? ', ${day.points} poin' : ''}',
              excludeSemantics: true,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${toWib(day.date).day}', style: Theme.of(context).textTheme.bodySmall),
                    Icon(icon, size: 14, color: color),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.result, required this.label});

  final String result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (color, icon, _) = _resultStyles[result]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16, color: color), const SizedBox(width: 4), Text(label)],
    );
  }
}
