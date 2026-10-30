import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/api_client.dart';
import '../../../core/platform.dart';
import '../../auth/providers.dart';
import '../../rewards/providers.dart';
import '../../usage/data/background_sync.dart';
import '../../usage/data/device_usage.dart';
import '../../usage/providers.dart';
import '../../usage/ui/usage_access_screen.dart';
import '../data/home_repository.dart';
import 'forecast_cards.dart';
import 'home_cards.dart';
import '../providers.dart';

/// S04 (docs/UI-KuotaPlus.md), tata letak mockup G.
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
      ref.invalidate(todayUsageProvider);
    } else if (isAndroidApp && !await hasUsageAccess() && !await usageOnboardingSeen() && mounted) {
      context.push('/onboarding/usage-access');
    }
  }

  Future<void> _refresh() {
    // Pemakaian hari ini dan kalender poin dimuat ulang bersama beranda.
    ref
      ..invalidate(todayUsageProvider)
      ..invalidate(pointsProvider);
    return ref.refresh(homeProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (home) {
          AsyncData(:final value) => RefreshIndicator(onRefresh: _refresh, child: _HomeContent(value)),
          AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(homeProvider)),
          _ => const SkeletonCardList(),
        },
      ),
    );
  }
}

class _HomeContent extends ConsumerStatefulWidget {
  const _HomeContent(this.snapshot);

  final HomeSnapshot snapshot;

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> {
  /// 0 = Paket aktif (bawaan), 1 = Hari ini.
  int _view = 0;

  static final _dayFormat = DateFormat('EEEE, d MMM', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final data = snapshot.data;
    final theme = Theme.of(context);
    final budget = data.dailyBudget;

    final blocks = <Widget>[
      if (snapshot.fromCache)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _Banner(text: 'Tidak bisa terhubung ke server. Data di bawah mungkin sudah berubah.'),
        ),
      SegmentedToggle(
        labels: const ['Paket aktif', 'Hari ini'],
        selected: _view,
        onChanged: (i) => setState(() => _view = i),
      ),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: Motion.of(context, Motion.enter),
        switchInCurve: Motion.enterCurve,
        switchOutCurve: Motion.exitCurve,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        child: switch ((_view, budget)) {
          (0, _) => ActiveQuotaCard(
              key: const ValueKey('paket'),
              subscriber: data.subscriber,
              subscriptions: data.subscriptions,
            ),
          (_, final b?) => DailyTank(key: const ValueKey('hari'), budgetBytes: b.budgetBytes, usedTodayBytes: b.usedTodayBytes),
          _ => const Card(
              key: ValueKey('hari-kosong'),
              child: EmptyState(
                title: 'Jatah harian belum tersedia',
                message: 'Jatah muncul setelah kamu punya paket aktif.',
              ),
            ),
        },
      ),
      const SizedBox(height: 12),
      const QuickMenu(),
      if (data.forecast != null) ...[const SizedBox(height: 12), ForecastCard(data.forecast!, now: data.serverTime)],
      if (data.teaser != null) ...[
        const SizedBox(height: 12),
        RecommendationTeaser(packageName: data.teaser!.packageName, saving: data.teaser!.saving),
      ],
      const TodayApps(),
      WeekStreak(balance: data.points.balance, streak: data.points.streak, today: data.serverTime),
    ];

    return ListView(
      // Selalu bisa ditarik untuk refresh walau isinya pendek.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayFormat.format(toWib(data.serverTime)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                  Text('Hai!', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24, height: 32 / 24)),
                  Text(
                    '${formatMsisdn(data.subscriber.msisdn)} · diperbarui ${DateFormat('HH.mm').format(toWib(data.serverTime))}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            PopupMenuButton<void>(
              tooltip: 'Menu akun',
              icon: const Icon(Icons.person_outline_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                fixedSize: const Size(48, 48),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(onTap: () => ref.read(authRepositoryProvider).logout(), child: const Text('Keluar')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Blok muncul bertahap sekali saat beranda pertama tampil.
        for (final (i, block) in blocks.indexed) EnterAnimation(index: i, child: block),
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
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger))),
        ],
      ),
    );
  }
}
