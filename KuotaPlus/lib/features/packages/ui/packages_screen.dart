import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../data/catalog_repository.dart';
import '../providers.dart';

/// S05 (docs/UI-KuotaPlus.md).
class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  String _type = 'bulanan';

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(packagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paket')),
      body: switch (groups) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(packagesProvider.future),
          child: _content(value.groups),
        ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(packagesProvider)),
        _ => const SkeletonCardList(),
      },
    );
  }

  Widget _content(List<PackageGroup> groups) {
    final packages = groups.where((g) => g.type == _type).expand((g) => g.packages).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in groups)
              ChoiceChip(
                label: Text(packageTypeLabels[group.type] ?? group.type),
                selected: group.type == _type,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _type = group.type);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (packages.isEmpty)
          const EmptyState(title: 'Belum ada paket di kategori ini.')
        else
          for (final package in packages) ...[_PackageCard(package), const SizedBox(height: 12)],
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard(this.package);

  final QuotaPackage package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = package;
    final perGb = formatPricePerGb(p.price, p.mainQuota);
    void buy() => context.push('/packages/${p.id}/checkout', extra: p);

    return PressScale(
      child: Card(
        // FR-3.3: rekomendasi utama terbaru untuk pengguna ini ditandai bingkai biru dan chip.
        shape: p.isRecommended
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
              )
            : null,
        child: InkWell(
          onTap: buy,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.isRecommended) ...[
                  const StatusChip(label: 'Paling hemat untukmu', color: AppColors.primary),
                  const SizedBox(height: 8),
                ],
                Text(p.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                // Anatomi kartu paket: kuota besar dulu, lalu masa aktif.
                Text(formatBytes(p.mainQuota), style: secondaryNumber),
                Text('Kuota utama · ${p.validityDays} hari', style: muted),
                if (p.appQuota > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+ ${formatBytes(p.appQuota)} ${categoryLabels[p.appCategory] ?? 'aplikasi'}',
                    style: theme.textTheme.labelLarge,
                  ),
                  if (p.appExamples.isNotEmpty) Text('Untuk ${p.appExamples.join(', ')}', style: muted),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatRupiah(p.price),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          // Harga per GB terbuka supaya paket bisa dibandingkan apa adanya.
                          if (perGb != null) Text('≈ $perGb utama', style: muted),
                        ],
                      ),
                    ),
                    FilledButton(onPressed: buy, child: const Text('Beli')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
