import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../../../core/models/transaction.dart';
import '../../home/providers.dart';
import '../../recommendations/providers.dart';
import '../../transactions/providers.dart';
import '../../transactions/ui/payment_form.dart';
import '../data/catalog_repository.dart';
import '../providers.dart';

/// S06 Checkout paket dengan tukar poin (FR-3.4, FR-12), tata letak mockup "Checkout" M10.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.package, this.recommendationId});

  final QuotaPackage package;

  /// Diisi jika dibuka dari layar rekomendasi, untuk metrik "dibeli dari rekomendasi" (FR-10.8).
  final int? recommendationId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _usePoints = false;
  int _points = 0;
  String _method = 'qris';

  @override
  Widget build(BuildContext context) {
    final p = widget.package;
    // Aturan dan saldo poin ikut respons katalog; saat belum termuat, checkout tetap bisa tanpa poin.
    final rules = ref.watch(packagesProvider).value?.points;
    final points = _usePoints ? _points : 0;
    final discount = rules == null ? 0 : points * rules.rupiahPerPoint;
    final total = p.price - discount;
    // Saldo pulsa dari beranda (tab yang selalu hidup). Tidak diketahui = biarkan server yang menolak.
    final pulsa = ref.watch(homeProvider).value?.data.subscriber.pulsaBalance;
    final short = pulsa == null ? 0 : total - pulsa;
    final options = [
      const PaymentMethodOption('qris'),
      const PaymentMethodOption('va'),
      const PaymentMethodOption('ewallet'),
      PaymentMethodOption(
        'pulsa',
        disabledReason: short > 0 ? 'Saldo ${formatRupiah(pulsa!)}, kurang ${formatRupiah(short)}' : null,
        fixLabel: 'Isi ulang pulsa dulu',
        onFix: () => context.push('/topup'),
      ),
    ];
    final method = options.any((o) => o.key == _method && o.enabled) ? _method : 'qris';
    final need = widget.recommendationId == null ? null : ref.watch(recommendationsProvider).value?.needBytes;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const BackHeader(title: 'Checkout'),
            EnterAnimation(child: _PackageHero(package: p, needBytes: need)),
            if (rules != null) ...[
              const SizedBox(height: 12),
              EnterAnimation(
                index: 1,
                child: _PointsPanel(
                  rules: rules,
                  price: p.price,
                  on: _usePoints,
                  value: _points,
                  onToggle: (on) => setState(() {
                    _usePoints = on;
                    if (on && _points == 0) _points = rules.maxPointsFor(p.price);
                  }),
                  onChanged: (v) => setState(() => _points = v),
                ),
              ),
            ],
            const SizedBox(height: 16),
            EnterAnimation(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle('Bayar pakai'),
                  PaymentMethodList(
                    options: options,
                    selected: method,
                    onChanged: (m) => setState(() => _method = m),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            EnterAnimation(
              index: 3,
              child: _PriceBreakdown(price: p.price, discount: discount, total: total),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PayBar(
        label: 'Bayar ${formatRupiah(total)}',
        // Poin atau metode berubah = isi permintaan berubah = Idempotency-Key baru.
        requestId: (points, method),
        caption: Row(
          children: [
            Expanded(
              child: Text('Bayar pakai ${paymentMethodLabels[method]}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
            ),
            if (discount > 0)
              Text('Hemat ${formatRupiah(discount)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      )),
          ],
        ),
        onSubmit: (key) => ref.read(transactionRepositoryProvider).create(
              type: 'package',
              packageId: p.id,
              pointsUsed: points,
              paymentMethod: method,
              idempotencyKey: key,
              recommendationId: widget.recommendationId,
            ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

class _PackageHero extends StatelessWidget {
  const _PackageHero({required this.package, this.needBytes});

  final QuotaPackage package;
  final int? needBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = package;
    final category = categoryLabels[p.appCategory]?.toLowerCase() ?? 'aplikasi';
    final enough = needBytes != null && p.mainQuota + p.appQuota >= needBytes!;

    return Panel(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(formatBytes(p.mainQuota), style: displayNumber.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
              if (p.appQuota > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('+ ${formatBytes(p.appQuota)} $category',
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          Text(
            [
              '${p.validityDays} hari',
              if (p.appQuota > 0 && p.appExamples.isNotEmpty) 'kuota $category untuk ${p.appExamples.join(', ')}',
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(enough ? Icons.check_rounded : Icons.info_outline_rounded,
                    size: 18, color: enough ? AppColors.success : AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enough
                        ? 'Cukup untuk pemakaianmu, ±${formatBytes(needBytes!)} sebulan'
                        : 'Aktif setelah dibayar dan berjalan bersama paket lain. Tidak menambah masa aktif nomor.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsPanel extends StatelessWidget {
  const _PointsPanel({
    required this.rules,
    required this.price,
    required this.on,
    required this.value,
    required this.onToggle,
    required this.onChanged,
  });

  final PointRules rules;
  final int price;
  final bool on;
  final int value;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChanged;

  /// Tiga pilihan siap pakai (kelipatan langkah tukar): terkecil, tengah, terbesar.
  List<int> _presets(int max) {
    final step = rules.redeemStep;
    final mid = (max ~/ 2) ~/ step * step;
    return {step, mid, max}.where((v) => v > 0 && v <= max).toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = rules.maxPointsFor(price);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pakai poin', style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(
                        'Kamu punya ${rules.balance} poin · ${rules.redeemStep} poin = ${formatRupiah(rules.redeemStep * rules.rupiahPerPoint)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                Switch(value: on && max > 0, onChanged: max == 0 ? null : onToggle),
              ],
            ),
          ),
          if (max == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                rules.balance < rules.redeemStep
                    ? 'Kumpulkan minimal ${rules.redeemStep} poin untuk mendapat potongan.'
                    : 'Poin belum bisa dipakai untuk paket ini.',
                style: muted,
              ),
            ),
          SmoothSize(
            child: on && max > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (final (i, p) in _presets(max).indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: _PresetTile(
                                points: p,
                                rupiah: p * rules.rupiahPerPoint,
                                selected: p == value,
                                onTap: () => onChanged(p),
                              )),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Maksimal ${rules.maxDiscountPercent}% dari harga paket.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.points, required this.rupiah, required this.selected, required this.onTap});

  final int points;
  final int rupiah;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = selected ? AppColors.primary : AppColors.text;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: PressScale(
        child: Material(
          color: selected ? AppColors.primaryContainer : AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$points poin', style: theme.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w800)),
                  Text('−${formatRupiah(rupiah)}', style: theme.textTheme.bodySmall?.copyWith(color: ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.price, required this.discount, required this.total});

  final int price;
  final int discount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);
    final strong = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]);

    Widget row(String label, String value, {TextStyle? valueStyle}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [Expanded(child: Text(label, style: muted)), Text(value, style: valueStyle ?? strong)]),
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Harga paket', formatRupiah(price)),
          row('Potongan poin', discount > 0 ? '−${formatRupiah(discount)}' : 'Rp0',
              valueStyle: strong?.copyWith(color: discount > 0 ? AppColors.success : null)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: rowDivider),
          Row(
            children: [
              Expanded(child: Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              CountUpText(
                value: total,
                format: formatRupiah,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Kuota aktif otomatis begitu pembayaran diterima. Harga ini sama untuk semua pelanggan.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.5)),
        ],
      ),
    );
  }
}
