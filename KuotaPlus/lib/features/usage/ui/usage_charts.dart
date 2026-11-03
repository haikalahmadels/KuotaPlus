import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../data/usage_repository.dart';

/// Gradasi satu warna menurut peringkat pemakaian (terbesar paling gelap); "Lainnya" abu-abu.
/// Identitas aplikasi dibawa legenda (nama + MB + %), bukan warna, jadi aman untuk buta warna
/// dan tidak bentrok dengan warna status hijau/merah (docs/UI-KuotaPlus.md).
const rankColors = [Color(0xFF104281), Color(0xFF1C5CAB), Color(0xFF2A78D6), Color(0xFF5598E7), Color(0xFF86B6EF)];
const othersColor = Color(0xFF9CA3AF);

Color usageColor(AppUsage app, int rank) => app.appId == null ? othersColor : rankColors[rank % rankColors.length];

const categoryIcons = {
  'video': Icons.play_circle_outline,
  'sosmed': Icons.forum_outlined,
  'game': Icons.sports_esports_outlined,
  'belajar': Icons.school_outlined,
  'umum': Icons.apps,
  'sistem': Icons.settings_suggest_outlined,
};

/// Donut top 5 + Lainnya (FR-8.2). [selected] menyorot satu irisan; yang lain meredup.
class UsageDonut extends StatelessWidget {
  const UsageDonut({super.key, required this.apps, required this.totalBytes, this.selected, this.size = 200});

  final List<AppUsage> apps;
  final int totalBytes;
  final int? selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = selected == null ? null : apps[selected!];

    return Semantics(
      label: 'Diagram pemakaian: ${apps.map((a) => '${a.label} ${a.percent}%').join(', ')}',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              duration: Motion.of(context, Motion.enter),
              curve: Motion.enterCurve,
              PieChartData(
                startDegreeOffset: -90,
                centerSpaceRadius: size * 0.32,
                sectionsSpace: 2, // celah 2px warna permukaan antar irisan
                sections: [
                  for (final (i, app) in apps.indexed)
                    PieChartSectionData(
                      value: app.bytes.toDouble(),
                      color: usageColor(app, i).withValues(alpha: selected == null || selected == i ? 1 : 0.25),
                      radius: size * (selected == i ? 0.17 : 0.14),
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  focus == null ? formatBytes(totalBytes) : '${focus.percent.round()}%',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  focus?.label ?? 'total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar pemakaian harian (FR-8.3) dengan garis putus-putus jatah harian saat ini sebagai pembanding.
/// Dengan jatah: hari yang lewat jatah merah (boros). Tanpa jatah: hari lonjakan kuning tua.
class DailyUsageChart extends StatelessWidget {
  const DailyUsageChart({super.key, required this.daily, this.budgetBytes});

  final List<DailyUsage> daily;
  final int? budgetBytes;

  static const _mb = 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final budgetMb = budgetBytes == null ? null : budgetBytes! / _mb;
    final maxMb = daily.fold<double>(budgetMb ?? 0, (max, d) => d.bytes / _mb > max ? d.bytes / _mb : max);
    final dense = daily.length > 10;

    return Semantics(
      label: 'Pemakaian harian ${daily.length} hari, tertinggi ${formatBytes((maxMb * _mb).round())}'
          '${budgetBytes == null ? '' : ', jatah harian ${formatBytes(budgetBytes!)}'}',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxMb == 0 ? 1 : maxMb * 1.15,
            extraLinesData: ExtraLinesData(horizontalLines: [
              if (budgetMb != null)
                HorizontalLine(
                  y: budgetMb,
                  color: AppColors.warning,
                  strokeWidth: 2,
                  dashArray: const [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: muted,
                    labelResolver: (_) => 'Jatah ${formatBytes(budgetBytes!)}',
                  ),
                ),
            ]),
            alignment: BarChartAlignment.spaceBetween,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) =>
                      value == meta.max ? const SizedBox() : Text(formatBytes((value * _mb).round()), style: muted),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    // 30 hari: label tiap 5 hari supaya tidak bertumpuk.
                    if (dense && (daily.length - 1 - i) % 5 != 0) return const SizedBox();
                    final date = toWib(daily[i].date);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(DateFormat(dense ? 'd/M' : 'E', 'id_ID').format(date), style: muted),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.text,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = daily[group.x];
                  return BarTooltipItem(
                    '${formatDate(day.date)}\n${formatBytes(day.bytes)}'
                    '${budgetBytes != null && day.bytes > budgetBytes! ? '\nLewat jatah' : day.isSpike ? '\nLonjakan' : ''}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
            barGroups: [
              for (final (i, day) in daily.indexed)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: day.bytes / _mb,
                    width: dense ? 6 : 16,
                    color: budgetBytes != null
                        ? (day.bytes > budgetBytes! ? AppColors.danger : AppColors.primary)
                        : (day.isSpike ? AppColors.warning : AppColors.primary),
                    borderRadius: BorderRadius.circular(dense ? 3 : 6),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
