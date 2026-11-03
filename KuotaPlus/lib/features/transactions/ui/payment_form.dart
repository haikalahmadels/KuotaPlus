import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/models/transaction.dart';

/// Satu baris pilihan metode bayar. [disabledReason] terisi = baris tidak bisa dipilih;
/// [fixLabel] + [onFix] memberi jalan keluar (misalnya isi ulang pulsa dulu).
class PaymentMethodOption {
  const PaymentMethodOption(this.key, {this.disabledReason, this.fixLabel, this.onFix});

  final String key;
  final String? disabledReason;
  final String? fixLabel;
  final VoidCallback? onFix;

  bool get enabled => disabledReason == null;
}

const _methodInfo = {
  'qris': (Icons.qr_code_2_rounded, 'Scan dari aplikasi bank atau e-wallet'),
  'va': (Icons.account_balance_rounded, 'Transfer dari m-banking'),
  'ewallet': (Icons.account_balance_wallet_rounded, 'Lanjut di aplikasi e-wallet'),
  'pulsa': (Icons.sim_card_rounded, 'Langsung terpotong dari saldo pulsa'),
};

IconData paymentMethodIcon(String method) => _methodInfo[method]?.$1 ?? Icons.payments_rounded;

/// Daftar metode bayar bergaya radio di satu panel putih (checkout S06).
class PaymentMethodList extends StatelessWidget {
  const PaymentMethodList({super.key, required this.options, required this.selected, required this.onChanged});

  final List<PaymentMethodOption> options;
  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = Motion.of(context, Motion.fade);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Material(
        color: AppColors.surface,
        child: Column(
          children: [
            for (final (i, o) in options.indexed) ...[
              if (i > 0) rowDivider,
              AnimatedContainer(
                duration: duration,
                color: o.key == selected ? AppColors.primaryContainer : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      inMutuallyExclusiveGroup: true,
                      checked: o.key == selected,
                      enabled: o.enabled,
                      button: true,
                      child: InkWell(
                        onTap: o.enabled && onChanged != null ? () => onChanged!(o.key) : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: !o.enabled
                                        ? AppColors.neutralContainer
                                        : o.key == selected
                                            ? AppColors.surface
                                            : AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    paymentMethodIcon(o.key),
                                    size: 20,
                                    color: o.enabled ? AppColors.primary : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        paymentMethodLabels[o.key] ?? o.key,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: o.enabled ? AppColors.text : AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        o.disabledReason ?? _methodInfo[o.key]?.$2 ?? '',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: o.enabled ? AppColors.textMuted : AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _RadioMark(selected: o.key == selected, enabled: o.enabled),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!o.enabled && o.fixLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 56, bottom: 4),
                        child: TextButton(onPressed: o.onFix, child: Text(o.fixLabel!)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fade),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 2,
          color: selected ? AppColors.primary : (enabled ? const Color(0xFF6B7280) : AppColors.border),
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: Motion.of(context, Motion.fade),
        curve: Curves.easeOutBack,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Bilah bayar yang menempel di bawah (S06, S07). Membuat transaksi lalu mengganti layar ke pembayaran (S08).
///
/// Idempotency-Key dibuat sekali per isi permintaan ([requestId], termasuk metode) dan dipakai ulang
/// untuk percobaan ulang setelah error jaringan, supaya tidak tercipta transaksi ganda.
class PayBar extends ConsumerStatefulWidget {
  const PayBar({
    super.key,
    required this.label,
    required this.onSubmit,
    required this.requestId,
    this.caption,
    this.enabled = true,
  });

  /// Teks tombol, sudah termasuk jumlahnya ("Bayar Rp60.000").
  final String label;
  final Future<Transaction> Function(String idempotencyKey) onSubmit;
  final Object? requestId;

  /// Baris kecil di atas tombol (metode, hemat poin).
  final Widget? caption;
  final bool enabled;

  @override
  ConsumerState<PayBar> createState() => _PayBarState();
}

class _PayBarState extends ConsumerState<PayBar> {
  String? _idempotencyKey;
  bool _loading = false;
  bool _done = false;
  ApiException? _error;

  @override
  void didUpdateWidget(PayBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) {
      _idempotencyKey = null;
      _error = null;
    }
  }

  Future<void> _pay() async {
    final key = _idempotencyKey ??= const Uuid().v4();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final transaction = await widget.onSubmit(key);
      if (!mounted) return;
      // Centang singkat sebagai konfirmasi sebelum pindah ke layar pembayaran.
      setState(() => _done = true);
      if (!Motion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) context.pushReplacement('/payment/${transaction.id}');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reachable = ref.watch(serverReachableProvider);
    final error = _error;
    // Saat offline tombol tetap bisa dipakai untuk mencoba lagi dengan key yang sama.
    final canPay = widget.enabled && !_loading && !_done && (reachable || _idempotencyKey != null);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x140F1E50), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(error.message, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
                ),
                if (error.code == 'INSUFFICIENT_BALANCE')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: () => context.push('/topup'), child: const Text('Isi ulang pulsa')),
                  ),
                const SizedBox(height: 8),
              ] else if (!reachable) ...[
                Text('Tidak bisa terhubung ke server. Pembayaran dinonaktifkan sementara.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
              ] else if (widget.caption != null) ...[
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: widget.caption),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: canPay ? _pay : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  backgroundColor: _done ? AppColors.success : null,
                  disabledBackgroundColor: _done ? AppColors.success : null,
                  disabledForegroundColor: _done ? AppColors.onPrimary : null,
                  textStyle: const TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fade),
                  child: _done
                      ? const Icon(Icons.check_rounded, key: ValueKey('done'), size: 26)
                      : _loading
                          ? const SizedBox.square(
                              key: ValueKey('loading'),
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                            )
                          : Text(error?.isNetwork == true ? 'Coba lagi' : widget.label, key: ValueKey(widget.label)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip status transaksi dengan warna sesuai arti (docs/UI-KuotaPlus.md, prinsip 2).
class TransactionStatusChip extends StatelessWidget {
  const TransactionStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: transactionStatusLabels[status] ?? status, color: transactionStatusColor(status));
}

Color transactionStatusColor(String status) => switch (status) {
      'paid' => AppColors.success,
      'pending' => AppColors.warning,
      'failed' => AppColors.danger,
      _ => AppColors.textMuted,
    };
