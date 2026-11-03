import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/subscriber.dart';
import '../../../core/models/transaction.dart';
import '../../home/providers.dart';
import '../../transactions/providers.dart';
import '../../transactions/ui/payment_form.dart';
import '../data/catalog_repository.dart';
import '../providers.dart';

/// FR-4.2: isi ulang tidak bisa dibayar dengan pulsa.
const _methods = ['qris', 'va', 'ewallet'];

/// S07 isi ulang pulsa, tata letak mockup "Isi ulang" M10.
class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({super.key});

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  int? _selected;
  String _method = _methods.first;

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(topupOptionsProvider);
    // Saldo dan masa aktif dari beranda; tanpa itu isi ulang tetap bisa, hanya tanpa pratinjau "jadi berapa".
    final subscriber = ref.watch(homeProvider).value?.data.subscriber;
    // Pilihan awal: nominal tengah, supaya pratinjau langsung terisi.
    final loaded = options.value;
    if (_selected == null && loaded != null && loaded.isNotEmpty) _selected = loaded[loaded.length ~/ 2].amount;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (options) {
          AsyncData(:final value) => _content(value, subscriber),
          AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(topupOptionsProvider)),
          _ => const SkeletonCardList(),
        },
      ),
      bottomNavigationBar: options.value == null
          ? null
          : PayBar(
              label: _selected == null ? 'Pilih nominal dulu' : 'Isi ulang ${formatRupiah(_selected!)}',
              enabled: _selected != null,
              requestId: (_selected, _method),
              onSubmit: (key) => ref.read(transactionRepositoryProvider).create(
                    type: 'topup',
                    topupAmount: _selected,
                    paymentMethod: _method,
                    idempotencyKey: key,
                  ),
            ),
    );
  }

  Widget _content(List<TopupOption> options, Subscriber? subscriber) {
    final theme = Theme.of(context);
    final selected = options.where((o) => o.amount == _selected).firstOrNull;
    final maxDays = options.fold(0, (m, o) => o.extendDays > m ? o.extendDays : m);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        BackHeader(
          title: 'Isi ulang pulsa',
          subtitle: subscriber == null ? null : formatMsisdn(subscriber.msisdn),
        ),
        if (subscriber != null)
          EnterAnimation(child: _AfterCard(subscriber: subscriber, option: selected, maxDays: maxDays)),
        const SizedBox(height: 16),
        EnterAnimation(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(theme, 'Pilih nominal'),
              LayoutBuilder(
                builder: (context, constraints) {
                  final half = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (i, o) in options.indexed)
                        SizedBox(
                          // Jumlah ganjil: nominal terakhir selebar penuh supaya tidak ada lubang.
                          width: options.length.isOdd && i == options.length - 1 ? constraints.maxWidth : half,
                          child: _OptionTile(
                            option: o,
                            selected: _selected == o.amount,
                            onTap: () => setState(() => _selected = o.amount),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EnterAnimation(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(theme, 'Bayar pakai'),
              Row(
                children: [
                  for (final (i, m) in _methods.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _ChoiceTile(
                        selected: _method == m,
                        onTap: () => setState(() => _method = m),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(paymentMethodIcon(m), size: 20, color: _method == m ? AppColors.primary : AppColors.text),
                            const SizedBox(height: 4),
                            Text(
                              m == 'va' ? 'Virtual acc.' : paymentMethodLabels[m]!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _method == m ? AppColors.primary : AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text('Pulsa masuk otomatis begitu pembayaran diterima.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _title(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

/// "Pulsamu jadi" + garis masa aktif: bagian biru tua memanjang sesuai tambahan hari dari nominal terpilih.
class _AfterCard extends StatelessWidget {
  const _AfterCard({required this.subscriber, required this.option, required this.maxDays});

  final Subscriber subscriber;
  final TopupOption? option;
  final int maxDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subscriber;
    final days = option?.extendDays ?? 0;
    // FR-4.3: perpanjangan dihitung dari masa aktif saat ini, bukan dari hari ini.
    final until = s.activeUntil.add(Duration(days: days));
    final current = s.daysLeft.toDouble();
    final span = current + (maxDays == 0 ? 1 : maxDays);
    final currentFrac = current / span;
    final endFrac = (current + days) / span;
    final short = DateFormat('d MMM', 'id_ID');
    final long = DateFormat('d MMMM yyyy', 'id_ID');
    final duration = Motion.of(context, Motion.enter);
    final label = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted);

    return Panel(
      hero: true,
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option == null ? 'Pulsamu sekarang' : 'Pulsamu jadi',
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            CountUpText(
              value: s.pulsaBalance + (option?.amount ?? 0),
              format: formatRupiah,
              style: displayNumber.copyWith(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            Text(
              option == null ? 'Pilih nominal untuk melihat hasilnya' : 'dari ${formatRupiah(s.pulsaBalance)} sekarang',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return ExcludeSemantics(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 16,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(left: 0, child: Text('Hari ini', style: label)),
                            if (currentFrac > 0.18 && currentFrac < 0.7)
                              Positioned(
                                left: w * currentFrac,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, 0),
                                  child: Text(short.format(toWib(s.activeUntil)), style: label),
                                ),
                              ),
                            if (days > 0)
                              AnimatedPositioned(
                                duration: duration,
                                curve: Motion.enterCurve,
                                right: w * (1 - endFrac.clamp(0.42, 1.0)),
                                child: Text(short.format(toWib(until)),
                                    style: label?.copyWith(color: AppColors.primary)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 12,
                          color: AppColors.surface,
                          child: Stack(
                            children: [
                              Positioned(left: 0, top: 0, bottom: 0, width: w * currentFrac,
                                  child: const ColoredBox(color: Color(0xFF5578D6))),
                              AnimatedPositioned(
                                duration: duration,
                                curve: Motion.enterCurve,
                                left: w * currentFrac,
                                top: 0,
                                bottom: 0,
                                width: w * (endFrac - currentFrac),
                                child: const ColoredBox(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Masa aktif '),
                if (days > 0) ...[
                  TextSpan(text: '+$days hari', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  TextSpan(text: ', sampai ${long.format(toWib(until))}'),
                ] else
                  TextSpan(text: 'sampai ${long.format(toWib(s.activeUntil))}'),
              ]),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.onTap});

  final TopupOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ChoiceTile(
      selected: selected,
      onTap: onTap,
      radius: 20,
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatRupiah(option.amount),
                style: secondaryNumber.copyWith(
                  fontSize: 20,
                  height: 26 / 20,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : AppColors.text,
                )),
            Text('+${option.extendDays} hari masa aktif', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Ubin pilihan: latar putih, terpilih = biru muda dengan cincin biru.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.onTap, required this.child, this.radius = 16, this.height = 64});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double radius;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: PressScale(
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fade),
          height: height,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: child),
          ),
        ),
      ),
    );
  }
}
