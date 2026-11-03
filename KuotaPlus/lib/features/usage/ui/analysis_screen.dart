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
import 'app_logo.dart';
import 'usage_charts.dart';

const _periods = {'today': 'Hari ini', '7d': '7 hari', '30d': '30 hari'};

/// S11: analisis pemakaian per aplikasi (FR-8), tata letak mockup "Analisis" M10.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(usageSummaryProvider);
    final period = ref.watch(usagePeriodProvider);
    final keys = _periods.keys.toList();
    final theme = Theme.of(context);
    final data = summary.value;
    final isDemo = data?.source == 'demo';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            // Android dengan izin: tarik data terbaru dari HP dulu, baru muat ulang analisis.
            await reportAndSyncUsage(ref.read(apiClientProvider));
            return ref.refresh(usageSummaryProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data?.lastSyncedAt == null
                              ? 'Pemakaian data seluler'
                              : 'Disinkronkan ${formatDateTime(data!.lastSyncedAt!)}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                        ),
                        Text('Analisis', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24, height: 32 / 24)),
                      ],
                    ),
                  ),
                  if (isDemo) const StatusChip(label: 'Data demo', color: AppColors.warning),
                  if (isDemo || !isAndroidApp)
                    IconButton(
                      tooltip: 'Ganti profil demo',
                      onPressed: () => showDemoSheet(context),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedToggle(
                labels: _periods.values.toList(),
                selected: keys.indexOf(period),
                onChanged: (i) => ref.read(usagePeriodProvider.notifier).select(keys[i]),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fade),
                child: switch (summary) {
                  AsyncData(:final value) => KeyedSubtree(
                      key: ValueKey(value.period),
                      child: value.hasData ? _Summary(value) : const _NoData(),
                    ),
                  AsyncError(:final error) =>
                    ErrorRetry(error: error, onRetry: () => ref.invalidate(usageSummaryProvider)),
                  _ => const SizedBox(height: 420, child: SkeletonCardList(count: 2)),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatefulWidget {
  const _Summary(this.summary);

  final UsageSummary summary;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  /// Aplikasi yang disorot di donat (indeks di topApps).
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);
    final s = widget.summary;
    final days = s.daily.length;
    final avg = days > 1 ? 'Rata-rata ${formatBytes(s.totalBytes ~/ days)} per hari' : null;
    final budget = s.dailyBudgetBytes;
    final top = s.topApps;
    final topBytes = top.isEmpty ? 1 : top.map((a) => a.bytes).reduce((a, b) => a > b ? a : b);

    final blocks = <Widget>[
      // Kartu utama: donat + total. Kuo sengaja tidak muncul di layar grafik.
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.hero)),
        child: s.totalBytes == 0
            ? Text('Belum ada pemakaian data seluler pada periode ini.', style: muted)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UsageDonut(apps: top, totalBytes: s.totalBytes, selected: _selected, size: 140),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total data seluler', style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            )),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: CountUpText(value: s.totalBytes, format: formatBytes, style: displayNumber),
                            ),
                            if (avg != null) Text(avg, style: muted),
                            if (avg == null && budget != null) Text('Jatah hari ini ${formatBytes(budget)}', style: muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Ketuk aplikasi di bawah untuk menyorotnya di grafik.', style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400,
                  )),
                ],
              ),
      ),
      if (top.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final (i, app) in top.indexed)
                  _TopAppRow(
                    app: app,
                    color: usageColor(app, i),
                    ratio: app.bytes / topBytes,
                    index: i,
                    selected: _selected == i,
                    onTap: () => setState(() => _selected = _selected == i ? null : i),
                  ),
              ],
            ),
          ),
        ),
      if (days > 1)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Per hari', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                DailyUsageChart(daily: s.daily, budgetBytes: budget),
                if (budget != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _Legend(color: AppColors.primary, label: 'Di bawah jatah'),
                      _Legend(color: AppColors.danger, label: 'Lewat jatah'),
                      _Legend(color: AppColors.warning, label: 'Jatah ${formatBytes(budget)}', dashed: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('Grafik per hari tersedia untuk periode 7 dan 30 hari.', style: muted),
        ),
      if (s.insights.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text('Yang perlu kamu tahu', style: theme.textTheme.titleMedium),
        ),
        for (final insight in s.insights)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(insight, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
      ],
      if (s.apps.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text('Semua aplikasi', style: theme.textTheme.titleMedium),
        ),
        Card(
          child: Column(
            children: [
              for (final app in s.apps)
                ListTile(
                  leading: AppLogo(packageName: app.packageName, label: app.label, category: app.category),
                  title: Text(app.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Text('${app.percent.toStringAsFixed(1).replaceAll('.', ',')}%'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatBytes(app.bytes), style: theme.textTheme.labelLarge),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                  onTap: () => context.push('/usage/apps/${app.appId}?period=${s.period}'),
                ),
            ],
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, block) in blocks.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: EnterAnimation(index: i, child: block),
          ),
      ],
    );
  }
}

/// Baris aplikasi teratas: logo asli, ukuran, persen, dan bar. Ketuk untuk menyorot di donat.
class _TopAppRow extends StatelessWidget {
  const _TopAppRow({
    required this.app,
    required this.color,
    required this.ratio,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final AppUsage app;
  final Color color;
  final double ratio;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '${app.label}, ${formatBytes(app.bytes)}, ${app.percent.round()} persen',
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  AppLogo(packageName: app.packageName, label: app.label, category: app.category),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(app.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            Text('${formatBytes(app.bytes)} · ${app.percent.round()}%', style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio),
                          duration: Motion.of(context, Motion.countUp + Durations.short2 * index),
                          curve: Motion.enterCurve,
                          builder: (context, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                            color: color,
                            backgroundColor: AppColors.neutralContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? SizedBox(
                width: 16,
                child: Row(children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(child: Container(height: 2, color: color)),
                    if (i < 2) const SizedBox(width: 2),
                  ],
                ]),
              )
            : Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        )),
      ],
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
