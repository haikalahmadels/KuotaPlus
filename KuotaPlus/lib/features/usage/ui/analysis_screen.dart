import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/format.dart';
import '../../../core/platform.dart';
import '../../home/providers.dart';
import '../data/device_usage.dart';
import '../data/usage_repository.dart';
import '../providers.dart';
import 'usage_charts.dart';

const _periods = {'today': 'Hari ini', '7d': '7 hari', '30d': '30 hari'};

/// S11: analisis pemakaian per aplikasi (FR-8).
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(usageSummaryProvider);
    final period = ref.watch(usagePeriodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analisis')),
      body: RefreshIndicator(
        onRefresh: () async {
          // Android dengan izin: tarik data terbaru dari HP dulu, baru muat ulang analisis.
          await reportAndSyncUsage(ref.read(apiClientProvider));
          return ref.refresh(usageSummaryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [for (final e in _periods.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {period},
              showSelectedIcon: false,
              onSelectionChanged: (selected) => ref.read(usagePeriodProvider.notifier).select(selected.single),
            ),
            const SizedBox(height: 16),
            switch (summary) {
              AsyncData(:final value) => value.hasData ? _Summary(value) : const _NoData(),
              AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(usageSummaryProvider)),
              _ => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            },
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.summary);

  final UsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final isDemo = summary.source == 'demo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (isDemo) ...[const StatusChip(label: 'Data demo', color: AppColors.warning), const SizedBox(width: 8)],
            Expanded(
              child: Text(
                summary.lastSyncedAt == null ? '' : 'Disinkronkan ${formatDateTime(summary.lastSyncedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (isDemo || !isAndroidApp)
              TextButton(onPressed: () => showDemoSheet(context), child: const Text('Ganti profil demo')),
          ],
        ),
        const SizedBox(height: 8),
        for (final insight in summary.insights) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline, color: AppColors.primary),
              title: Text(insight),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: summary.totalBytes == 0
                ? Text('Belum ada pemakaian data seluler pada periode ini.', style: muted)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UsageDonut(apps: summary.topApps, totalBytes: summary.totalBytes),
                      const SizedBox(height: 12),
                      for (final (i, app) in summary.topApps.indexed) _LegendRow(app: app, color: usageColor(app, i)),
                    ],
                  ),
          ),
        ),
        if (summary.daily.length > 1) ...[
          const SizedBox(height: 24),
          Text('Pemakaian harian', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          DailyUsageChart(daily: summary.daily),
        ],
        if (summary.apps.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Semua aplikasi', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          for (final app in summary.apps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(categoryIcons[app.category] ?? Icons.apps),
              title: Text(app.label),
              subtitle: Text('${app.percent.toStringAsFixed(1).replaceAll('.', ',')}%'),
              trailing: Text(formatBytes(app.bytes), style: theme.textTheme.labelLarge),
              onTap: () => context.push('/usage/apps/${app.appId}?period=${summary.period}'),
            ),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.app, required this.color});

  final AppUsage app;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(app.label, style: theme.textTheme.bodyLarge)),
          Text('${formatBytes(app.bytes)} · ${app.percent.round()}%', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Empty state per platform (FR-8.6, edge case Izin).
class _NoData extends ConsumerWidget {
  const _NoData();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final granted = ref.watch(usageAccessProvider).value ?? false;

    final (title, body) = !isAndroidApp
        ? ('Belum ada data pemakaian', 'Buka Kuota+ di Android untuk mengirim data, atau pakai Mode Demo.')
        : granted
            ? ('Belum ada data pemakaian', 'Pemakaian data seluler akan muncul setelah sinkronisasi. Tarik layar ke bawah untuk mencoba.')
            : ('Beri izin data pemakaian', 'Tanpa izin, analisis, prediksi, rekomendasi, dan reward belum bisa dihitung. Cek kuota dan beli paket tetap bisa.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (isAndroidApp && !granted) ...[
              FilledButton(onPressed: () => context.push('/onboarding/usage-access'), child: const Text('Beri izin')),
              const SizedBox(height: 8),
            ],
            OutlinedButton(onPressed: () => showDemoSheet(context), child: const Text('Pakai Mode Demo')),
          ],
        ),
      ),
    );
  }
}

/// S13: pilih profil Mode Demo (FR-7.8).
Future<void> showDemoSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _DemoSheet(),
    );

class _DemoSheet extends ConsumerStatefulWidget {
  const _DemoSheet();

  @override
  ConsumerState<_DemoSheet> createState() => _DemoSheetState();
}

class _DemoSheetState extends ConsumerState<_DemoSheet> {
  static const _profiles = {
    'rina': ('Rina', 'Mahasiswa, ±800 MB/hari, banyak TikTok dan Instagram'),
    'budi': ('Budi', 'Sales lapangan, ±380 MB/hari, WhatsApp dan Maps'),
    'random': ('Acak', 'Pemakaian acak sekitar 600 MB/hari'),
  };

  String? _loading;
  String? _error;

  Future<void> _generate(String profile) async {
    setState(() {
      _loading = profile;
      _error = null;
    });
    try {
      await ref.read(usageRepositoryProvider).generateDemo(profile);
      ref
        ..invalidate(usageSummaryProvider)
        ..invalidate(homeProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mode Demo', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Membuat pemakaian 30 hari dari profil contoh. Data ditandai "Data demo" dan tidak memotong kuotamu.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final MapEntry(key: profile, value: (name, description)) in _profiles.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: _loading == null,
                title: Text(name),
                subtitle: Text(description),
                trailing: _loading == profile
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onTap: () => _generate(profile),
              ),
            if (_error != null) Text(_error!, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.danger)),
          ],
        ),
      ),
    );
  }
}
