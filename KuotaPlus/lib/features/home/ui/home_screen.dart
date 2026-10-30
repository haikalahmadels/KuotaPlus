import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/mascot.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../../../core/models/subscriber.dart';
import '../../../core/models/subscription.dart';
import '../../../core/api_client.dart';
import '../../../core/platform.dart';
import '../../auth/providers.dart';
import '../../usage/data/background_sync.dart';
import '../../usage/data/device_usage.dart';
import '../../usage/providers.dart';
import '../../usage/ui/usage_access_screen.dart';
import '../data/home_repository.dart';
import 'forecast_cards.dart';
import '../providers.dart';

/// S04 (docs/UI-KuotaPlus.md).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _onAppOpened();
  }

  /// FR-7.5: sync pemakaian saat aplikasi dibuka, lalu jadwal 6 jam. Izin belum ada → tawarkan sekali (FR-7.1).
  Future<void> _onAppOpened() async {
    if (isAndroidApp) scheduleUsageSync();

    final synced = await reportAndSyncUsage(ref.read(apiClientProvider));
    if (!mounted) return;

    if (synced) {
      ref.invalidate(homeProvider);
      ref.invalidate(usageSummaryProvider);
    } else if (isAndroidApp && !await hasUsageAccess() && !await usageOnboardingSeen() && mounted) {
      context.push('/onboarding/usage-access');
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'Menu',
            itemBuilder: (context) => [
              PopupMenuItem(onTap: () => ref.read(authRepositoryProvider).logout(), child: const Text('Keluar')),
            ],
          ),
        ],
      ),
      body: switch (home) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(homeProvider.future),
          child: _HomeContent(value),
        ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(homeProvider)),
        _ => const SkeletonCardList(),
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent(this.snapshot);

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final data = snapshot.data;
    final theme = Theme.of(context);

    return ListView(
      // Selalu bisa ditarik untuk refresh walau isinya pendek.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (snapshot.fromCache) ...[
          const _Banner(text: 'Tidak bisa terhubung ke server. Data di bawah mungkin sudah berubah.'),
          const SizedBox(height: 8),
        ],
        Text(
          'Diperbarui ${formatDateTime(data.serverTime)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        // Angka utama layar: sisa kuota (docs/UI-KuotaPlus.md, S04). Pulsa menjadi angka pendukung.
        if (data.subscriptions.isEmpty)
          const _NoQuotaCard()
        else
          for (final (i, subscription) in data.subscriptions.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            _SubscriptionCard(subscription, lead: i == 0),
          ],
        if (data.forecast != null) ...[const SizedBox(height: 12), ForecastCard(data.forecast!)],
        if (data.dailyBudget != null) ...[
          const SizedBox(height: 12),
          DailyBudgetCard(budgetBytes: data.dailyBudget!.budgetBytes, usedTodayBytes: data.dailyBudget!.usedTodayBytes),
        ],
        const SizedBox(height: 12),
        _PulsaCard(data.subscriber),
        if (data.teaser != null) ...[
          const SizedBox(height: 12),
          RecommendationTeaser(packageName: data.teaser!.packageName, saving: data.teaser!.saving),
        ],
        const SizedBox(height: 12),
        PointsTile(balance: data.points.balance, streak: data.points.streak),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _PulsaCard extends StatelessWidget {
  const _PulsaCard(this.subscriber);

  final Subscriber subscriber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pulsa', style: muted),
                      Text(formatRupiah(subscriber.pulsaBalance), style: secondaryNumber),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/topup'),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Isi ulang'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (subscriber.inGrace) ...[
              StatusChip(label: 'Masa tenggang s.d. ${formatDate(subscriber.graceUntil!)}', color: AppColors.warning),
              const SizedBox(height: 4),
              Text(
                'Isi ulang agar nomor tetap aktif. Selama masa tenggang kamu tidak bisa membeli paket.',
                style: muted,
              ),
            ] else
              Text('Aktif s.d. ${formatDate(subscriber.activeUntil)} · ${subscriber.daysLeft} hari lagi', style: muted),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard(this.subscription, {required this.lead});

  final Subscription subscription;

  /// Kartu pertama memuat angka terbesar di layar; kartu lain memakai angka pendukung.
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subscription;
    final hasApp = s.appTotal > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (s.isExhausted)
              const _ExhaustedNotice()
            else ...[
              _QuotaRow(
                label: hasApp ? 'Utama' : null,
                remaining: s.mainRemaining,
                total: s.mainTotal,
                style: lead ? displayNumber : secondaryNumber,
              ),
              if (hasApp) ...[
                const SizedBox(height: 12),
                _QuotaRow(
                  label: categoryLabels[s.appCategory] ?? 'Aplikasi',
                  remaining: s.appRemaining,
                  total: s.appTotal,
                  style: secondaryNumber,
                ),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Berakhir ${formatDateTime(s.expiresAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kuota habis: Kuo mengantuk, nada tenang, satu jalan keluar.
class _ExhaustedNotice extends StatelessWidget {
  const _ExhaustedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const Mascot(mood: MascotMood.sleepy, size: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusChip(label: 'Kuota habis', color: AppColors.danger),
              const SizedBox(height: 4),
              Text('Kuo lagi istirahat. Beli paket supaya bisa internetan lagi.', style: theme.textTheme.bodyMedium),
              TextButton(onPressed: () => context.go('/packages'), child: const Text('Lihat paket')),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.label, required this.remaining, required this.total, required this.style});

  final String? label;
  final int remaining;
  final int total;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : remaining / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) Text(label!, style: theme.textTheme.labelLarge),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            CountUpText(value: remaining, format: formatBytes, style: style),
            const SizedBox(width: 6),
            Text(
              'dari ${formatBytes(total)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: Motion.of(context, Motion.countUp),
          curve: Motion.enterCurve,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            backgroundColor: AppColors.neutralContainer,
            // semanticsValue harus angka; keterangan lengkap dibacakan lewat label.
            semanticsLabel: 'Sisa kuota ${label ?? ''} ${formatBytes(remaining)} dari ${formatBytes(total)}',
          ),
        ),
      ],
    );
  }
}

class _NoQuotaCard extends StatelessWidget {
  const _NoQuotaCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: EmptyState(
        mood: MascotMood.sleepy,
        title: 'Kamu tidak punya kuota aktif',
        message: 'Pilih paket yang pas dengan pemakaianmu.',
        actionLabel: 'Lihat paket',
        onAction: () => context.go('/packages'),
      ),
    );
  }
}
