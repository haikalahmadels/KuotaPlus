import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/api_exception.dart';
import '../../../core/format.dart';
import '../../../core/models/transaction.dart';
import '../../home/providers.dart';
import '../providers.dart';
import 'payment_form.dart';

/// S08: menunggu pembayaran dan hasilnya (FR-5.3, FR-5.7).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  static const _pollInterval = Duration(seconds: 3);

  Transaction? _transaction;
  Object? _error;
  Timer? _poll;
  Timer? _clock;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // FR-5.7: cek sekali lagi saat kembali dari aplikasi pembayaran (simulator).
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final transaction = await ref.read(transactionRepositoryProvider).get(widget.transactionId);
      if (!mounted) return;
      final settled = _transaction?.isPending == true && !transaction.isPending;
      setState(() {
        _transaction = transaction;
        _error = null;
      });
      if (transaction.isPending) {
        _poll ??= Timer.periodic(_pollInterval, (_) => _refresh());
        _clock ??= Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      } else {
        _stopTimers();
        if (settled || transaction.status == 'paid') _invalidateAffected();
      }
    } on ApiException catch (e) {
      // Error jaringan sesaat tidak menghentikan polling; layar tetap menampilkan data terakhir.
      if (mounted && _transaction == null) setState(() => _error = e);
    }
  }

  void _stopTimers() {
    _poll?.cancel();
    _clock?.cancel();
    _poll = _clock = null;
  }

  /// Pulsa, paket, dan riwayat berubah setelah transaksi selesai.
  void _invalidateAffected() {
    ref.invalidate(homeProvider);
    ref.invalidate(transactionHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: transaction == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator())
              : ErrorRetry(error: _error!, onRetry: _refresh))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Summary(transaction),
                const SizedBox(height: 16),
                if (transaction.isPending) _PendingInstructions(transaction) else _Result(transaction),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.transaction);

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.itemName, style: theme.textTheme.titleLarge)),
                TransactionStatusChip(t.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatRupiah(t.netAmount), style: displayNumber),
            Text('${paymentMethodLabels[t.paymentMethod]} · ${t.externalRef}', style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

class _PendingInstructions extends StatelessWidget {
  const _PendingInstructions(this.transaction);

  final Transaction transaction;

  Future<void> _openPaymentApp(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(transaction.payment!.simulatorUrl),
      // Android: Custom Tabs, seolah membuka aplikasi bank. Web: tab baru.
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Halaman pembayaran tidak bisa dibuka.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = transaction.payment!;
    final left = transaction.expiresAt!.difference(DateTime.now());
    final remaining = left.isNegative ? Duration.zero : left;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bayar dalam ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
          style: theme.textTheme.titleLarge?.copyWith(color: AppColors.warning),
        ),
        Text('Batas ${formatDateTime(transaction.expiresAt!)}', style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 16),
        if (payment.vaNumber != null)
          Card(
            child: ListTile(
              title: Text('Nomor ${payment.bankLabel}'),
              subtitle: Text(payment.vaNumber!, style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 1)),
              trailing: IconButton(
                tooltip: 'Salin nomor VA',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: payment.vaNumber!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor VA disalin.')));
                },
              ),
            ),
          ),
        if (payment.qrString != null)
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: payment.qrString!, size: 220, semanticsLabel: 'Kode QRIS'),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _openPaymentApp(context),
          child: Text(transaction.paymentMethod == 'ewallet' ? 'Buka E-Wallet' : 'Buka simulator pembayaran'),
        ),
        const SizedBox(height: 12),
        Text(
          'Status diperbarui otomatis. Kamu bisa menutup layar ini; transaksi tetap ada di Riwayat '
          'dengan tombol "Lanjutkan bayar".',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result(this.transaction);

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, message) = switch (transaction.status) {
      'paid' => (
          Icons.check_circle,
          AppColors.success,
          transaction.type == 'package' ? 'Paket sudah aktif dan bisa langsung dipakai.' : 'Pulsa dan masa aktif sudah bertambah.',
        ),
      'expired' => (Icons.timer_off, AppColors.textMuted, 'Waktu pembayaran habis. Silakan buat transaksi baru.'),
      _ => (Icons.cancel, AppColors.danger, 'Pembayaran ditolak. Tidak ada saldo yang terpotong.'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, color: color, size: 64),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => context.go('/home'), child: const Text('Ke Beranda')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => context.go('/history'), child: const Text('Lihat riwayat')),
      ],
    );
  }
}
