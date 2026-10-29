import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../data/catalog_repository.dart';
import '../providers.dart';

/// S07 (docs/UI-KuotaPlus.md). Pembayaran ditambahkan di M3.
class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({super.key});

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(topupOptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Isi ulang')),
      body: switch (options) {
        AsyncData(:final value) => _content(value),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(topupOptionsProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _content(List<TopupOption> options) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Pilih nominal', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Isi ulang juga menambah masa aktif nomor.', style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            for (final option in options) _OptionTile(
              option: option,
              selected: _selected == option.amount,
              onTap: () => setState(() => _selected = option.amount),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Pembayaran segera tersedia.'))),
          child: const Text('Lanjut bayar'),
        ),
      ],
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

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Semantics(
          selected: selected,
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatRupiah(option.amount), style: theme.textTheme.titleLarge),
                Text('+${option.extendDays} hari masa aktif', style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
