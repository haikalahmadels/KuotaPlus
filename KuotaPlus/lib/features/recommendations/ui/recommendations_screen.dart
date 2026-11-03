import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/mascot.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../data/recommendation_repository.dart';
import '../providers.dart';

/// S14: rekomendasi paket hemat (FR-10, US-09, US-10), tata letak mockup "Rekomendasi" M10.
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(recommendationsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(recommendationsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: [
              const BackHeader(title: 'Paket untukmu', subtitle: 'Dihitung dari pemakaian 30 hari terakhir'),
              ...switch (recommendations) {
                AsyncData(:final value) => _content(context, ref, value),
                AsyncError(:final error) => [
                    ErrorRetry(error: error, onRetry: () => ref.invalidate(recommendationsProvider)),
                  ],
                _ => [const SkeletonBox(width: double.infinity, height: 360)],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, Recommendations r) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);

    if (r.status == 'insufficient_data') {
      return const [
        EmptyState(
          mood: MascotMood.sleepy,
          title: 'Rekomendasi tersedia setelah 7 hari pemakaian',
          message: 'Kuota+ butuh pola pemakaian seminggu penuh supaya paket yang disarankan benar-benar cukup.',
        ),
      ];
    }
    if (r.items.isEmpty) {
      return [
        Panel(child: Text('Belum ada paket di katalog yang cukup untuk pemakaianmu.', style: muted)),
      ];
    }

    final top = r.items.first;
    final rest = r.items.skip(1).toList();

    return [
      if (r.status == 'already_cheapest') ...[
        Panel(
          color: AppColors.successContainer,
          child: Row(
            children: [
              const Icon(Icons.check_rounded, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Paketmu sekarang sudah paling hemat.',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      EnterAnimation(child: _TopCard(item: top, needBytes: r.needBytes, spent30d: r.spent30d)),
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 18),
        EnterAnimation(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Pilihan lain yang juga cukup',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        for (final (i, item) in rest.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          EnterAnimation(index: i + 2, child: _AltCard(item: item, top: top, needBytes: r.needBytes)),
        ],
      ],
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Harga sama untuk semua pelanggan. Rekomendasi dihitung ulang tiap pemakaianmu atau katalog berubah.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.5),
        ),
      ),
    ];
  }
}

Future<void> _buy(BuildContext context, WidgetRef ref, RecommendationItem item) async {
  ref.read(recommendationRepositoryProvider).click(item.id);
  await context.push('/packages/${item.package.id}/checkout', extra: (item.package, item.id));
}

/// "12 GB utama + 16 GB video · 30 hari".
String _packageLine(QuotaPackage p) {
  final app = p.appQuota > 0 ? ' + ${formatBytes(p.appQuota)} ${categoryLabels[p.appCategory]?.toLowerCase() ?? 'aplikasi'}' : '';
  return '${formatBytes(p.mainQuota)} utama$app · ${p.validityDays} hari';
}

/// Total kuota paket (utama + aplikasi), dasar perbandingan dengan kebutuhan.
int _packageBytes(QuotaPackage p) => p.mainQuota + p.appQuota;

class _TopCard extends ConsumerStatefulWidget {
  const _TopCard({required this.item, required this.needBytes, required this.spent30d});

  final RecommendationItem item;
  final int? needBytes;
  final int? spent30d;

  @override
  ConsumerState<_TopCard> createState() => _TopCardState();
}

class _TopCardState extends ConsumerState<_TopCard> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final p = item.package;
    final need = widget.needBytes;
    final saving = item.saving30d;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);

    return Panel(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(saving != null && saving > 0 ? 'Paling pas dan paling hemat' : 'Paling pas untukmu',
              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(p.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(_packageLine(p), style: muted),
          if (need != null) ...[
            const SizedBox(height: 16),
            _FitMeter(needBytes: need, packageBytes: _packageBytes(p), leftoverBytes: item.leftoverBytes),
          ],
          const SizedBox(height: 16),
          if (saving != null && widget.spent30d != null)
            Row(
              children: [
                Expanded(
                  child: _CompareBox(
                    label: 'Belanja paketmu 30 hari terakhir',
                    value: formatRupiah(widget.spent30d!),
                    muted: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompareBox(
                    label: 'Dengan paket ini',
                    value: formatRupiah(item.cost30d),
                    note: saving > 0
                        ? 'Hemat ${formatRupiah(saving)}/bulan'
                        : saving == 0
                            ? 'Sama, tapi lebih pas'
                            : '${formatRupiah(-saving)} lebih mahal, tapi cukup sebulan',
                    noteColor: saving > 0 ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            )
          else
            _CompareBox(label: 'Biaya per 30 hari', value: formatRupiah(item.cost30d)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _why = !_why),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 44)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Kenapa paket ini?'),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _why ? 0.5 : 0,
                  duration: Motion.of(context, Motion.fade),
                  child: const Icon(Icons.expand_more_rounded, size: 20),
                ),
              ],
            ),
          ),
          SmoothSize(
            child: _why
                ? Panel(
                    padding: const EdgeInsets.all(14),
                    child: Text(item.reason, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          PressScale(
            child: FilledButton(
              onPressed: () => _buy(context, ref, item),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Pilih paket ini · ${formatRupiah(p.price)}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Batang kecukupan: seberapa penuh paket terpakai oleh kebutuhan 30 hari.
class _FitMeter extends StatelessWidget {
  const _FitMeter({required this.needBytes, required this.packageBytes, required this.leftoverBytes});

  final int needBytes;
  final int packageBytes;
  final int leftoverBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = packageBytes == 0 ? 0.0 : (needBytes / packageBytes).clamp(0.0, 1.0);
    final strong = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]);
    final text = 'Kebutuhanmu ±${formatBytes(needBytes)} dari ${formatBytes(packageBytes)}, '
        '${leftoverBytes > 0 ? 'sisa ±${formatBytes(leftoverBytes)}' : 'pas'}';

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Kebutuhanmu ', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  TextSpan(text: '±${formatBytes(needBytes)}', style: strong),
                ])),
              ),
              Text(formatBytes(packageBytes), style: strong),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Container(
              height: 14,
              color: AppColors.surface,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fill),
                duration: Motion.of(context, const Duration(milliseconds: 800)),
                curve: Motion.enterCurve,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  leftoverBytes > 0 ? 'Cukup, masih sisa ±${formatBytes(leftoverBytes)}' : 'Cukup sebulan penuh',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareBox extends StatelessWidget {
  const _CompareBox({required this.label, required this.value, this.note, this.noteColor, this.muted = false});

  final String label;
  final String value;
  final String? note;
  final Color? noteColor;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: muted ? Colors.transparent : AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: muted ? AppColors.textMuted : AppColors.primary,
              )),
          Text(value,
              style: secondaryNumber.copyWith(
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w800,
                color: muted ? AppColors.textMuted : AppColors.text,
              )),
          if (note != null)
            Text(note!, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: noteColor)),
        ],
      ),
    );
  }
}

class _AltCard extends ConsumerWidget {
  const _AltCard({required this.item, required this.top, required this.needBytes});

  final RecommendationItem item;
  final RecommendationItem top;
  final int? needBytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = item.package;
    final diff = item.cost30d - top.cost30d;
    final bytes = _packageBytes(p);
    final fill = needBytes == null || bytes == 0 ? null : (needBytes! / bytes).clamp(0.0, 1.0);

    return PressScale(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => _buy(context, ref, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(_packageLine(p), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatRupiah(item.cost30d),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )),
                        if (diff != 0)
                          Text(diff > 0 ? '+${formatRupiah(diff)}' : '−${formatRupiah(-diff)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: diff > 0 ? AppColors.warning : AppColors.success,
                              )),
                      ],
                    ),
                  ],
                ),
                if (fill != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fill,
                            minHeight: 6,
                            color: const Color(0xFF5578D6),
                            backgroundColor: AppColors.neutralContainer,
                            semanticsLabel: 'Kecukupan',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          item.leftoverBytes > 0 ? 'Sisa ±${formatBytes(item.leftoverBytes)} tak terpakai' : 'Pas',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
