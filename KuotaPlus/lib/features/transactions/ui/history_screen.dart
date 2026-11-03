import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import 'transaction_detail_screen.dart';

/// S09: tab Pembelian (FR-6) dan Berbagi (FR-14), tata letak mockup "Riwayat" M10.
/// `?tab=berbagi` membuka tab Berbagi (dari layar selesai berbagi).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sharing = GoRouterState.of(context).uri.queryParameters['tab'] == 'berbagi';
    // Key ikut query supaya tab berpindah saat route yang sama dibuka dengan ?tab berbeda.
    return _History(key: ValueKey(sharing), sharing: sharing);
  }
}

class _History extends StatefulWidget {
  const _History({super.key, required this.sharing});

  final bool sharing;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  late int _tab = widget.sharing ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Riwayat', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26, height: 32 / 26, fontWeight: FontWeight.w800)),
                  Text('Pembelian, isi ulang, dan berbagi kuota',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedToggle(
                labels: const ['Pembelian', 'Berbagi'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fade),
                child: _tab == 0 ? const _PurchaseList(key: ValueKey(0)) : const _ShareList(key: ValueKey(1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _filters = {'all': 'Semua', 'pending': 'Menunggu', 'paid': 'Berhasil', 'failed': 'Gagal'};

/// "Gagal" juga mencakup kedaluwarsa: keduanya tidak menagih biaya dan butuh "Beli lagi".
bool _matches(Transaction t, String filter) =>
    filter == 'all' || t.status == filter || (filter == 'failed' && t.status == 'expired');

class _PurchaseList extends ConsumerStatefulWidget {
  const _PurchaseList({super.key});

  @override
  ConsumerState<_PurchaseList> createState() => _PurchaseListState();
}

class _PurchaseListState extends ConsumerState<_PurchaseList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(transactionHistoryProvider);

    return switch (history) {
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(transactionHistoryProvider.future),
          child: _list(context, value),
        ),
      AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(transactionHistoryProvider)),
      _ => const SkeletonCardList(),
    };
  }

  Widget _list(BuildContext context, TransactionPage page) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    if (page.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            mood: MascotMood.rest,
            title: 'Belum ada transaksi',
            message: 'Paket dan isi ulang yang kamu beli akan muncul di sini.',
            actionLabel: 'Lihat paket',
            onAction: () => context.go('/packages'),
          ),
        ],
      );
    }

    final pending = page.items
        .where((t) => t.isPending && t.expiresAt != null && t.expiresAt!.isAfter(now))
        .firstOrNull;
    final shown = page.items.where((t) => _matches(t, _filter)).toList();
    final groups = <String, List<Transaction>>{};
    for (final t in shown) {
      groups.putIfAbsent(formatDayLabel(t.createdAt, now), () => []).add(t);
    }
    var row = 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (pending != null) ...[
          EnterAnimation(child: _PendingCard(pending)),
          const SizedBox(height: 12),
        ],
        if (_MonthSummary.compute(page, now) case final summary?)
          EnterAnimation(index: 1, child: summary),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(:key, :value) in _filters.entries)
              _FilterChip(
                label: value,
                count: page.items.where((t) => _matches(t, key)).length,
                selected: _filter == key,
                onTap: () => setState(() => _filter = key),
              ),
          ],
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Panel(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text('Tidak ada transaksi ${_filters[_filter]!.toLowerCase()}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(page.hasMore ? 'Di halaman yang sudah dimuat.' : 'Coba lihat semua transaksi.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(() => _filter = 'all'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Tampilkan semua'),
                  ),
                ],
              ),
            ),
          ),
        for (final MapEntry(key: day, value: items) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(day, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Material(
              color: AppColors.surface,
              child: Column(
                children: [
                  for (final (i, t) in items.indexed) ...[
                    if (i > 0) rowDivider,
                    EnterAnimation(index: (row++).clamp(0, 6), child: _TransactionRow(t)),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (page.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: () => ref.read(transactionHistoryProvider.notifier).loadMore(),
              child: const Text('Muat lagi'),
            ),
          ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard(this.t);

  final Transaction t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = theme.textTheme.bodySmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600);

    return Panel(
      color: AppColors.warningContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Belum dibayar', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                    Text('${t.itemName} · ${formatRupiah(t.netAmount)}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Countdown(
                    until: t.expiresAt!,
                    builder: (left) => Semantics(
                      label: 'Sisa waktu bayar $left',
                      excludeSemantics: true,
                      child: Text(left,
                          style: secondaryNumber.copyWith(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w800, color: AppColors.warning)),
                    ),
                  ),
                  Text('sisa waktu', style: warn),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/payment/${t.id}'),
                  child: const Text('Lanjutkan bayar'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => showTransactionSheet(context, t),
                style: FilledButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.text),
                child: const Text('Detail'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Belanja bulan ini (WIB) dari transaksi berhasil. Hanya tampil jika semua transaksi bulan ini sudah termuat,
/// supaya angkanya tidak kurang karena halaman berikutnya belum dimuat.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.month, required this.spent, required this.saved, required this.count, required this.weeks, required this.currentWeek});

  final String month;
  final int spent;
  final int saved;
  final int count;
  final List<int> weeks;
  final int currentWeek;

  static _MonthSummary? compute(TransactionPage page, DateTime now) {
    final today = toWib(now);
    bool inMonth(Transaction t) {
      final d = toWib(t.createdAt);
      return d.year == today.year && d.month == today.month;
    }

    final complete = !page.hasMore || !inMonth(page.items.last);
    final paid = page.items.where((t) => t.status == 'paid' && inMonth(t)).toList();
    if (!complete || paid.isEmpty) return null;

    final weeks = List.filled(((DateUtils.getDaysInMonth(today.year, today.month) - 1) ~/ 7) + 1, 0);
    for (final t in paid) {
      weeks[(toWib(t.createdAt).day - 1) ~/ 7] += t.netAmount;
    }
    return _MonthSummary(
      month: DateFormat('MMMM', 'id_ID').format(today),
      spent: paid.fold(0, (s, t) => s + t.netAmount),
      saved: paid.fold(0, (s, t) => s + t.discountAmount),
      count: paid.length,
      weeks: weeks,
      currentWeek: (today.day - 1) ~/ 7,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = weeks.fold(1, (m, w) => w > m ? w : m);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);

    return Panel(
      hero: true,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Belanja $month', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CountUpText(
                  value: spent,
                  format: formatRupiah,
                  style: displayNumber.copyWith(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
              ),
              Semantics(
                label: 'Belanja per minggu: ${weeks.map(formatRupiah).join(', ')}',
                excludeSemantics: true,
                child: SizedBox(
                  height: 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (i, w) in weeks.indexed) ...[
                        if (i > 0) const SizedBox(width: 5),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: w / top),
                          duration: Motion.of(context, Motion.countUp),
                          curve: Motion.enterCurve,
                          builder: (context, v, _) => Container(
                            width: 10,
                            height: 4 + 30 * v,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: i == currentWeek ? AppColors.primary : const Color(0xFF5578D6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$count transaksi berhasil'),
              if (saved > 0) ...[
                const TextSpan(text: ' · '),
                TextSpan(
                  text: 'hemat ${formatRupiah(saved)}',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' dari poin'),
              ],
            ]),
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? AppColors.onPrimary : AppColors.text;

    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count',
      excludeSemantics: true,
      child: PressScale(
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fade),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                    const SizedBox(width: 6),
                    Text('$count',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ink, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.t);

  final Transaction t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topup = t.type == 'topup';
    final stopped = t.status == 'failed' || t.status == 'expired';

    return InkWell(
      onTap: () => showTransactionSheet(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: topup ? AppColors.skyContainer : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(topup ? Icons.add_circle_outline_rounded : Icons.sell_outlined,
                  size: 20, color: topup ? AppColors.sky : AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.itemName, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('${formatTime(t.createdAt)} · ${paymentMethodLabels[t.paymentMethod] ?? t.paymentMethod}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(t.netAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: stopped ? const Color(0xFF6B7280) : AppColors.text,
                    decoration: stopped ? TextDecoration.lineThrough : null,
                  ),
                ),
                // Hanya yang butuh perhatian diberi label; transaksi berhasil cukup tanpa label.
                if (t.status != 'paid')
                  Text(transactionStatusLabels[t.status] ?? t.status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: transactionStatusColor(t.status),
                      )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab Berbagi: riwayat sebagai pengirim (FR-14.13). Kuota yang diterima tampil di beranda.
class _ShareList extends ConsumerWidget {
  const _ShareList({super.key});

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
              : _list(context, ref, value),
        ),
      AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(shareHistoryProvider)),
      _ => const SkeletonCardList(),
    };
  }

  Widget _list(BuildContext context, WidgetRef ref, QuotaTransferPage page) {
    final theme = Theme.of(context);
    final done = page.items.where((t) => t.status == 'completed').toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // Total hanya jika seluruh riwayat sudah termuat, supaya angkanya tidak kurang.
        if (!page.hasMore && done.isNotEmpty)
          EnterAnimation(
            child: Panel(
              hero: true,
              color: AppColors.violetContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kamu sudah berbagi',
                      style: theme.textTheme.labelLarge?.copyWith(color: AppColors.violet, fontWeight: FontWeight.w700)),
                  Text(formatGb(done.fold(0, (s, t) => s + t.bytes)),
                      style: displayNumber.copyWith(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  Text(
                    'ke ${done.map((t) => t.recipientMasked).toSet().length} nomor · '
                    '${done.fold(0, (s, t) => s + t.pointsSpent)} poin terpakai',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Material(
            color: AppColors.surface,
            child: Column(
              children: [
                for (final (i, t) in page.items.indexed) ...[
                  if (i > 0) rowDivider,
                  EnterAnimation(index: i.clamp(0, 6), child: _ShareRow(t)),
                ],
              ],
            ),
          ),
        ),
        if (page.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: () => ref.read(shareHistoryProvider.notifier).loadMore(),
              child: const Text('Muat lagi'),
            ),
          ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => context.push('/share'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Bagi kuota lagi'),
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow(this.t);

  final QuotaTransfer t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = t.status == 'completed';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.violetContainer, shape: BoxShape.circle),
            child: const Icon(Icons.ios_share_rounded, color: AppColors.violet, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ke ${t.recipientMasked}', style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  '${formatDate(t.completedAt ?? t.recipientExpiresAt)} · berlaku s.d. ${formatDate(t.recipientExpiresAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatGb(t.bytes),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              if (!completed)
                Text('Gagal', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
