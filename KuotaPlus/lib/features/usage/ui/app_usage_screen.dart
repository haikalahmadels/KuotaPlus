import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../data/usage_repository.dart';
import '../providers.dart';
import 'usage_charts.dart';

final _appUsageProvider = FutureProvider.autoDispose.family<AppUsageDetail, (int, String)>(
  (ref, args) => ref.watch(usageRepositoryProvider).app(args.$1, args.$2),
);

/// S12: tren harian satu aplikasi dan rata-ratanya (FR-8.4).
class AppUsageScreen extends ConsumerWidget {
  const AppUsageScreen({super.key, required this.appId, required this.period});

  final int appId;
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_appUsageProvider((appId, period)));

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.label ?? 'Detail aplikasi')),
      body: switch (detail) {
        AsyncData(:final value) => _Detail(value),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(_appUsageProvider((appId, period)))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.detail);

  final AppUsageDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Widget stat(String label, int bytes) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label, style: muted), Text(formatBytes(bytes), style: theme.textTheme.titleLarge)],
              ),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(categoryIcons[detail.category] ?? Icons.apps),
            const SizedBox(width: 8),
            Text('Kategori ${detail.category}', style: muted),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [stat('Total', detail.totalBytes), const SizedBox(width: 12), stat('Rata-rata per hari', detail.avgDailyBytes)]),
        if (detail.daily.length > 1) ...[
          const SizedBox(height: 24),
          Text('Tren harian', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          DailyUsageChart(daily: detail.daily),
        ],
      ],
    );
  }
}
