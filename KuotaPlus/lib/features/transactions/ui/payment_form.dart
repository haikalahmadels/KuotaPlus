import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/format.dart';
import '../../../core/models/transaction.dart';

/// Pilihan metode + tombol bayar, dipakai checkout paket (S06) dan isi ulang (S07).
/// Setelah transaksi dibuat, layar diganti dengan layar pembayaran (S08).
class PaymentForm extends ConsumerStatefulWidget {
  const PaymentForm({
    super.key,
    required this.methods,
    required this.total,
    required this.onSubmit,
    this.requestId,
  });

  final List<String> methods;

  /// Null = belum ada item dipilih, tombol bayar nonaktif.
  final int? total;

  /// Membuat transaksi dengan metode dan Idempotency-Key yang diberikan.
  final Future<Transaction> Function(String method, String idempotencyKey) onSubmit;

  /// Identitas isi permintaan selain metode (misalnya nominal isi ulang). Berubah = Idempotency-Key baru.
  final Object? requestId;

  @override
  ConsumerState<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<PaymentForm> {
  late String _method = widget.methods.first;
  String? _idempotencyKey;
  bool _loading = false;
  ApiException? _error;

  @override
  void didUpdateWidget(PaymentForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) _idempotencyKey = null;
  }

  void _selectMethod(String method) => setState(() {
        _method = method;
        _idempotencyKey = null; // isi permintaan berubah
        _error = null;
      });

  Future<void> _pay() async {
    // Key yang sama dipakai untuk percobaan ulang setelah error jaringan, supaya tidak tercipta transaksi ganda.
    final key = _idempotencyKey ??= const Uuid().v4();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final transaction = await widget.onSubmit(_method, key);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Metode pembayaran', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _method,
          onChanged: (value) => _loading || value == null ? null : _selectMethod(value),
          child: Column(
            children: [
              for (final method in widget.methods)
                RadioListTile<String>(
                  value: method,
                  title: Text(paymentMethodLabels[method] ?? method),
                  subtitle: method == 'pulsa' ? const Text('Langsung terpotong dari saldo pulsa') : null,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text('Total bayar', style: theme.textTheme.bodyLarge)),
            Text(widget.total == null ? '-' : formatRupiah(widget.total!), style: theme.textTheme.titleLarge),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error.message, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.danger)),
          if (error.code == 'INSUFFICIENT_BALANCE')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => context.push('/topup'), child: const Text('Isi ulang pulsa')),
            ),
        ],
        if (!reachable) ...[
          const SizedBox(height: 12),
          Text('Tidak bisa terhubung ke server. Pembayaran dinonaktifkan sementara.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          // Saat offline tombol tetap bisa dipakai untuk mencoba lagi dengan key yang sama.
          onPressed: _loading || widget.total == null || (!reachable && _idempotencyKey == null) ? null : _pay,
          child: _loading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(error?.isNetwork == true ? 'Coba lagi' : 'Bayar'),
        ),
      ],
    );
  }
}

/// Chip status transaksi dengan warna sesuai arti (docs/UI-KuotaPlus.md, prinsip 2).
class TransactionStatusChip extends StatelessWidget {
  const TransactionStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'paid' => AppColors.success,
      'pending' => AppColors.warning,
      'failed' => AppColors.danger,
      _ => AppColors.textMuted,
    };

    return StatusChip(label: transactionStatusLabels[status] ?? status, color: color);
  }
}
