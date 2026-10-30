import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/forecast.dart';

/// FR-2.2 / FR-9: "Kuota diperkirakan habis [tanggal]" + Aman/Berisiko. Di luar kartu utama (mockup G);
/// saat berisiko bisa dibuka untuk linimasa, saran jatah, dan tombol ke rekomendasi.
class ForecastCard extends StatefulWidget {
  const ForecastCard(this.forecast, {super.key, this.now});

  final Forecast forecast;

  /// Titik "hari ini" di linimasa; default jam perangkat.
  final DateTime? now;

  @override
  State<ForecastCard> createState() => _ForecastCardState();
}

class _ForecastCardState extends State<ForecastCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);
    final f = widget.forecast;

    final (String title, String body) = switch (f) {
      Forecast(confidence: 'none') => ('Prediksi belum tersedia', 'Kumpulkan data pemakaian 3 hari dulu.'),
      Forecast(predictedEmptyAt: null) => ('Kuota aman sampai paket berakhir', 'Pemakaian data selulermu hampir nol.'),
      Forecast(isRisk: true) => (
          'Kuota diperkirakan habis ${formatDate(f.predictedEmptyAt!)}',
          '${f.daysEarly} hari lebih cepat dari paket berakhir (${formatDate(f.mainExpiresAt)}).',
        ),
      _ => ('Kuota diperkirakan habis ${formatDate(f.predictedEmptyAt!)}', 'Setelah paket berakhir ${formatDate(f.mainExpiresAt)}.'),
    };

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (f.status != null || f.confidence == 'low') ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (f.status != null)
                      StatusChip(
                        label: f.isRisk ? 'Berisiko' : 'Aman',
                        color: f.isRisk ? AppColors.warning : AppColors.success,
                      ),
                    if (f.confidence == 'low') const StatusChip(label: 'Perkiraan awal', color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(body, style: muted),
            ],
          ),
        ),
        if (f.isRisk)
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: Motion.of(context, Motion.enter),
            curve: Motion.enterCurve,
            child: const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
          ),
      ],
    );

    return PressScale(
      enabled: f.isRisk,
      child: Card(
        child: InkWell(
          onTap: f.isRisk ? () => setState(() => _open = !_open) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(expanded: f.isRisk ? _open : null, child: header),
                SmoothSize(
                  child: _open && f.isRisk
                      ? _Details(f, now: widget.now ?? DateTime.now())
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details(this.forecast, {required this.now});

  final Forecast forecast;
  final DateTime now;

  /// "5 Nov 2026" → "5 Nov" untuk label linimasa yang sempit.
  static String _short(DateTime time) => formatDate(time).split(' ').take(2).join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = forecast;
    final span = f.mainExpiresAt.difference(now).inMinutes;
    final at = span <= 0 ? 0.0 : (f.predictedEmptyAt!.difference(now).inMinutes / span).clamp(0.0, 1.0);
    // Agar cukup sampai paket berakhir: sisa kuota dibagi hari tersisa.
    final daysLeft = (span / (60 * 24)).ceil();
    final safeDaily = daysLeft <= 0 ? null : f.remainingBytes ~/ daysLeft;
    final label = theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Linimasa: hari ini, kuota habis ${formatDate(f.predictedEmptyAt!)}, '
                'paket berakhir ${formatDate(f.mainExpiresAt)}',
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, box) {
                final x = box.maxWidth * at;
                return SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 8,
                        width: x,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      Positioned(left: 0, top: 22, child: Text('Hari ini', style: label?.copyWith(color: AppColors.textMuted))),
                      Positioned(
                        // Label tanggal habis di bawah titiknya, tanpa menabrak label ujung kiri dan kanan.
                        left: (x - 40).clamp(56.0, math.max(56.0, box.maxWidth - 136)),
                        top: 22,
                        width: 80,
                        child: Text(
                          'Habis ${_short(f.predictedEmptyAt!)}',
                          textAlign: TextAlign.center,
                          style: label?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 22,
                        child: Text(_short(f.mainExpiresAt), style: label?.copyWith(color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (f.avgDailyBytes != null) 'Rata-rata pemakaianmu ${formatBytes(f.avgDailyBytes!)} per hari.',
              if (safeDaily != null)
                'Agar cukup sampai ${formatDate(f.mainExpiresAt)}, pakai paling banyak ${formatBytes(safeDaily)} per hari.',
            ].join(' '),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: () => context.push('/recommendations'), child: const Text('Lihat paket hemat')),
          ),
        ],
      ),
    );
  }
}

/// FR-2.4: teaser rekomendasi, hanya jika ada penghematan.
class RecommendationTeaser extends StatelessWidget {
  const RecommendationTeaser({super.key, required this.packageName, required this.saving});

  final String packageName;
  final int saving;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Card(
        color: AppColors.successContainer,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: const Icon(Icons.savings_outlined, color: AppColors.success),
          title: Text('Hemat ${formatRupiah(saving)}/bulan', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('dengan $packageName'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/recommendations'),
        ),
      ),
    );
  }
}
