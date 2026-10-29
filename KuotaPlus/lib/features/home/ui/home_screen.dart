import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../../../core/models/subscriber.dart';
import '../../../core/models/subscription.dart';
import '../../auth/providers.dart';
import '../data/home_repository.dart';
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
    ref.read(homeRepositoryProvider).reportDevice();
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
              PopupMenuItem(
                onTap: () => ref.read(authRepositoryProvider).logout(),
                child: const Text('Keluar'),
              ),
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
        _ => const Center(child: CircularProgressIndicator()),
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
        Text('Diperbarui ${formatDateTime(data.serverTime)}', style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        _PulsaCard(data.subscriber),
        const SizedBox(height: 24),
        Text('Kuota aktif', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.subscriptions.isEmpty)
          const _NoQuotaCard()
        else
          for (final subscription in data.subscriptions) ...[
            _SubscriptionCard(subscription),
            const SizedBox(height: 12),
          ],
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
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pulsa', style: muted),
            Text(formatRupiah(subscriber.pulsaBalance), style: displayNumber),
            const SizedBox(height: 4),
            if (subscriber.inGrace) ...[
              StatusChip(label: 'Masa tenggang s.d. ${formatDate(subscriber.graceUntil!)}', color: AppColors.warning),
              const SizedBox(height: 4),
              Text('Isi ulang agar nomor tetap aktif. Selama masa tenggang kamu tidak bisa membeli paket.', style: muted),
            ] else
              Text('Aktif s.d. ${formatDate(subscriber.activeUntil)} · ${subscriber.daysLeft} hari lagi', style: muted),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => context.push('/topup'), child: const Text('Isi ulang')),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard(this.subscription);

  final Subscription subscription;

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
            Text(s.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (s.isExhausted)
              const StatusChip(label: 'Kuota habis', color: AppColors.danger)
            else ...[
              _QuotaRow(label: hasApp ? 'Utama' : null, remaining: s.mainRemaining, total: s.mainTotal),
              if (hasApp) ...[
                const SizedBox(height: 12),
                _QuotaRow(
                  label: categoryLabels[s.appCategory] ?? 'Aplikasi',
                  remaining: s.appRemaining,
                  total: s.appTotal,
                ),
              ],
            ],
            const SizedBox(height: 12),
            Text('Berakhir ${formatDateTime(s.expiresAt)}', style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.label, required this.remaining, required this.total});

  final String? label;
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (label != null) ...[
              SizedBox(width: 72, child: Text(label!, style: theme.textTheme.labelLarge)),
            ],
            Text(formatBytes(remaining), style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
            const SizedBox(width: 6),
            Text('tersisa dari ${formatBytes(total)}', style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: total == 0 ? 0 : remaining / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: AppColors.border,
          semanticsLabel: 'Sisa kuota ${label ?? ''}',
          semanticsValue: '${formatBytes(remaining)} dari ${formatBytes(total)}',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kamu tidak punya kuota aktif', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/packages'), child: const Text('Lihat paket')),
          ],
        ),
      ),
    );
  }
}
