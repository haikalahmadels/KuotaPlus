import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/forecast.dart';

/// FR-2.2 / FR-9: "Kuota diperkirakan habis [tanggal]" + Aman/Berisiko.
class ForecastCard extends StatelessWidget {
  const ForecastCard(this.forecast, {super.key});

  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final f = forecast;

    final (String title, String body) = switch (f) {
      Forecast(confidence: 'none') => ('Prediksi belum tersedia', 'Kumpulkan data pemakaian 3 hari dulu.'),
      Forecast(predictedEmptyAt: null) => ('Kuota aman sampai paket berakhir', 'Pemakaian data selulermu hampir nol.'),
      Forecast(isRisk: true) => (
          'Kuota diperkirakan habis ${formatDate(f.predictedEmptyAt!)}',
          '${f.daysEarly} hari lebih cepat dari paket berakhir (${formatDate(f.mainExpiresAt)}). Coba hemat atau lihat rekomendasi paket.',
        ),
      _ => ('Kuota diperkirakan habis ${formatDate(f.predictedEmptyAt!)}', 'Setelah paket berakhir ${formatDate(f.mainExpiresAt)}.'),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: f.isRisk ? () => context.push('/recommendations') : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (f.status != null || f.confidence == 'low') const SizedBox(height: 8),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(body, style: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// FR-2.3: "Jatah hari ini X MB, terpakai Y MB" dengan progress bar.
class DailyBudgetCard extends StatelessWidget {
  const DailyBudgetCard({super.key, required this.budgetBytes, required this.usedTodayBytes});

  final int budgetBytes;
  final int usedTodayBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = usedTodayBytes > budgetBytes;
    final ratio = budgetBytes == 0 ? 1.0 : (usedTodayBytes / budgetBytes).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jatah hari ini', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(formatBytes(budgetBytes), style: displayNumber),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: AppColors.border,
              color: over ? AppColors.danger : AppColors.primary,
              // semanticsValue harus angka; keterangan lengkap dibacakan lewat label.
              semanticsLabel: 'Pemakaian hari ini ${formatBytes(usedTodayBytes)} dari jatah ${formatBytes(budgetBytes)}',
            ),
            const SizedBox(height: 8),
            Text(
              over
                  ? 'Terpakai ${formatBytes(usedTodayBytes)}, lewat ${formatBytes(usedTodayBytes - budgetBytes)} dari jatah'
                  : 'Terpakai ${formatBytes(usedTodayBytes)}, sisa ${formatBytes(budgetBytes - usedTodayBytes)}',
              style: theme.textTheme.bodyLarge?.copyWith(color: over ? AppColors.danger : null),
            ),
          ],
        ),
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.savings_outlined, color: AppColors.success),
        title: Text('Hemat ${formatRupiah(saving)}/bulan'),
        subtitle: Text('dengan $packageName'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/recommendations'),
      ),
    );
  }
}
