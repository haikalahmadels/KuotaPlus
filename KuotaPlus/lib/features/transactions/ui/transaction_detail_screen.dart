import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/transaction.dart';
import '../providers.dart';
import 'payment_form.dart';

final _transactionProvider = FutureProvider.autoDispose.family<Transaction, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).get(id),
);

/// S10: detail transaksi (FR-6.2) sebagai layar penuh, untuk deep link `/history/:id`.
/// Dari daftar riwayat, detail yang sama tampil sebagai bottom sheet ([showTransactionSheet]).
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(_transactionProvider(transactionId));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const BackHeader(title: 'Detail transaksi'),
            switch (transaction) {
              AsyncData(:final value) => Panel(padding: const EdgeInsets.all(20), child: TransactionDetailBody(value)),
              AsyncError(:final error) =>
                ErrorRetry(error: error, onRetry: () => ref.invalidate(_transactionProvider(transactionId))),
              _ => const SkeletonBox(width: double.infinity, height: 320),
            },
          ],
        ),
      ),
    );
  }
}

Future<void> showTransactionSheet(BuildContext context, Transaction transaction) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: TransactionDetailBody(transaction, inSheet: true),
      ),
    );

/// Isi detail ala struk: jumlah besar + status, urutan status, rincian, nomor ref yang bisa disalin, satu aksi.
class TransactionDetailBody extends StatelessWidget {
  const TransactionDetailBody(this.transaction, {super.key, this.inSheet = false});

  final Transaction transaction;
  final bool inSheet;

  void _go(BuildContext context, String location, {bool push = true}) {
    if (inSheet) Navigator.of(context).pop();
    push ? context.push(location) : context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;
    final retry = t.status == 'failed' || t.status == 'expired';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.itemName, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        Row(
          children: [
            Expanded(
              child: Text(formatRupiah(t.netAmount),
                  style: displayNumber.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
            ),
            TransactionStatusChip(t.status),
          ],
        ),
        const SizedBox(height: 16),
        _StatusSteps(t),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              _row(theme, 'Harga', formatRupiah(t.grossAmount)),
              if (t.discountAmount > 0)
                _row(theme, 'Potongan ${t.pointsUsed} poin', '−${formatRupiah(t.discountAmount)}', color: AppColors.success),
              _row(theme, 'Dibayar lewat', paymentMethodLabels[t.paymentMethod] ?? t.paymentMethod),
              _CopyRef(t.externalRef),
            ],
          ),
        ),
        if (t.isPending) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _go(context, '/payment/${t.id}'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: t.expiresAt == null
                ? const Text('Lanjutkan bayar')
                : Countdown(until: t.expiresAt!, builder: (left) => Text('Lanjutkan bayar · $left')),
          ),
        ],
        if (retry) ...[
          const SizedBox(height: 12),
          Text(
            '${t.status == 'failed' ? 'Pembayaran tidak berhasil.' : 'Tidak dibayar sampai batas waktu.'} Tidak ada biaya yang ditagihkan.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: () => t.type == 'topup' ? _go(context, '/topup') : _go(context, '/packages', push: false),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.primary,
            ),
            child: Text(t.type == 'topup' ? 'Isi ulang lagi' : 'Beli lagi'),
          ),
        ],
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted))),
            Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      );
}

class _CopyRef extends StatefulWidget {
  const _CopyRef(this.ref);

  final String ref;

  @override
  State<_CopyRef> createState() => _CopyRefState();
}

class _CopyRefState extends State<_CopyRef> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.ref));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () => mounted ? setState(() => _copied = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text('Nomor ref', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted))),
        Semantics(
          liveRegion: true,
          label: _copied ? 'Nomor ref tersalin' : 'Salin nomor ref ${widget.ref}',
          excludeSemantics: true,
          button: true,
          child: TextButton.icon(
            onPressed: _copy,
            style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.only(left: 8)),
            iconAlignment: IconAlignment.end,
            icon: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fade),
              child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, key: ValueKey(_copied), size: 16),
            ),
            label: Text(_copied ? 'Tersalin' : widget.ref,
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ),
      ],
    );
  }
}

/// Urutan status ala struk: titik hijau = selesai, kuning = sedang, merah = berhenti, abu = belum.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps(this.t);

  final Transaction t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = t.type == 'topup' ? 'Pulsa masuk' : 'Kuota aktif';
    final steps = <(String, DateTime?, Color)>[
      ('Pesanan dibuat', t.createdAt, AppColors.success),
      ...switch (t.status) {
        'paid' => [('Pembayaran diterima', t.paidAt, AppColors.success), (done, t.paidAt, AppColors.success)],
        'pending' => [('Menunggu pembayaran', null, AppColors.warning), (done, null, AppColors.noData)],
        'failed' => [('Pembayaran tidak berhasil', null, AppColors.danger)],
        _ => [('Batas waktu habis', t.expiresAt, AppColors.danger)],
      },
    ];

    return Semantics(
      label: 'Status: ${steps.map((s) => s.$1).join(', ')}',
      excludeSemantics: true,
      child: Column(
        children: [
          for (final (i, (label, time, color)) in steps.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color == AppColors.noData ? AppColors.surface : color,
                            border: Border.all(
                              color: color == AppColors.noData ? AppColors.noData : AppColors.containerOf(color),
                              width: 3,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              color: steps[i + 1].$3 == AppColors.success ? AppColors.success : AppColors.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: color == AppColors.noData ? FontWeight.w500 : FontWeight.w700,
                            color: color == AppColors.noData ? AppColors.textMuted : AppColors.text,
                          )),
                    ),
                  ),
                  if (time != null)
                    Text(formatTime(time), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Sisa waktu menuju [until] dalam "jj:mm:dd", diperbarui tiap detik (fungsional, tetap jalan saat animasi dikurangi).
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.until, required this.builder});

  final DateTime until;
  final Widget Function(String left) builder;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    final s = left.isNegative ? 0 : left.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return widget.builder('${two(s ~/ 3600)}:${two(s ~/ 60 % 60)}:${two(s % 60)}');
  }
}
