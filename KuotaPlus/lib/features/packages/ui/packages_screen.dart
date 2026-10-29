import 'package:flutter/material.dart';
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
        _ => const Center(child: CircularProgressIndicator()),
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
                onSelected: (_) => setState(() => _type = group.type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (packages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text('Belum ada paket di kategori ini.', textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
          )
        else
          for (final package in packages) ...[
            _PackageCard(package),
            const SizedBox(height: 12),
          ],
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
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = package;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FR-3.3: rekomendasi utama terbaru untuk pengguna ini.
            if (p.isRecommended) ...[
              const StatusChip(label: 'Paling hemat untukmu', color: AppColors.primary),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(p.name, style: theme.textTheme.titleLarge)),
                Text(formatRupiah(p.price), style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 4),
            Text('${formatBytes(p.mainQuota)} utama · ${p.validityDays} hari', style: theme.textTheme.bodyLarge),
            if (p.appQuota > 0) ...[
              Text('+ ${formatBytes(p.appQuota)} ${categoryLabels[p.appCategory] ?? 'aplikasi'}',
                  style: theme.textTheme.bodyLarge),
              if (p.appExamples.isNotEmpty) Text('Untuk ${p.appExamples.join(', ')}', style: muted),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => context.push('/packages/${p.id}/checkout', extra: p),
                child: const Text('Beli'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
