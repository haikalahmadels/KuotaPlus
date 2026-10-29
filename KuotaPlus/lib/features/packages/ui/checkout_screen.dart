import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../../transactions/providers.dart';
import '../../transactions/ui/payment_form.dart';
import '../data/catalog_repository.dart';
import '../providers.dart';

/// S06 Checkout paket dengan tukar poin (FR-3.4, FR-12).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.package, this.recommendationId});

  final QuotaPackage package;

  /// Diisi jika dibuka dari layar rekomendasi, untuk metrik "dibeli dari rekomendasi" (FR-10.8).
  final int? recommendationId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _points = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.package;
    // Aturan dan saldo poin ikut respons katalog; saat belum termuat, checkout tetap bisa tanpa poin.
    final rules = ref.watch(packagesProvider).value?.points;
    final discount = rules == null ? 0 : _points * rules.rupiahPerPoint;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('${formatBytes(p.mainQuota)} utama · ${p.validityDays} hari', style: theme.textTheme.bodyLarge),
                  if (p.appQuota > 0)
                    Text('+ ${formatBytes(p.appQuota)} ${categoryLabels[p.appCategory] ?? 'aplikasi'}',
                        style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Paket aktif setelah dibayar dan berjalan bersama paket lain. Membeli paket tidak menambah masa aktif nomor.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (rules != null) ...[
            const SizedBox(height: 16),
            _PointsInput(
              rules: rules,
              price: p.price,
              value: _points,
              onChanged: (points) => setState(() => _points = points),
            ),
          ],
          const SizedBox(height: 24),
          if (discount > 0) ...[
            _AmountRow(label: 'Harga paket', value: formatRupiah(p.price)),
            _AmountRow(label: 'Diskon $_points poin', value: '-${formatRupiah(discount)}'),
            const SizedBox(height: 8),
          ],
          PaymentForm(
            methods: const ['pulsa', 'ewallet', 'va', 'qris'],
            total: p.price - discount,
            // Jumlah poin berubah = isi permintaan berubah = Idempotency-Key baru.
            requestId: _points,
            onSubmit: (method, key) => ref.read(transactionRepositoryProvider).create(
                  type: 'package',
                  packageId: p.id,
                  pointsUsed: _points,
                  paymentMethod: method,
                  idempotencyKey: key,
                  recommendationId: widget.recommendationId,
                ),
          ),
        ],
      ),
    );
  }
}

class _PointsInput extends StatelessWidget {
  const _PointsInput({required this.rules, required this.price, required this.value, required this.onChanged});

  final PointRules rules;
  final int price;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final max = rules.maxPointsFor(price);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tukar poin', style: theme.textTheme.titleLarge),
            Text('Saldo ${rules.balance} poin · 1 poin = ${formatRupiah(rules.rupiahPerPoint)}', style: muted),
            if (max == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  rules.balance < rules.redeemStep
                      ? 'Kumpulkan minimal ${rules.redeemStep} poin untuk mendapat diskon.'
                      : 'Poin belum bisa dipakai untuk paket ini.',
                  style: muted,
                ),
              )
            else ...[
              Slider(
                value: value.toDouble(),
                max: max.toDouble(),
                divisions: max ~/ rules.redeemStep,
                label: '$value poin',
                semanticFormatterCallback: (v) => '${v.round()} poin',
                onChanged: (v) => onChanged(v.round()),
              ),
              Row(
                children: [
                  Expanded(child: Text('$value poin = diskon ${formatRupiah(value * rules.rupiahPerPoint)}', style: theme.textTheme.bodyLarge)),
                  TextButton(onPressed: () => onChanged(max), child: Text('Pakai $max')),
                ],
              ),
              Text('Maksimal ${rules.maxDiscountPercent}% dari harga paket, kelipatan ${rules.redeemStep} poin.', style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
