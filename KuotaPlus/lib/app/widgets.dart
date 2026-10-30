import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_exception.dart';
import 'mascot.dart';
import 'theme.dart';

/// Pesan error yang aman ditampilkan ke pengguna.
String errorMessage(Object error) => error is ApiException ? error.message : 'Terjadi kesalahan. Coba lagi.';

/// State error standar: pesan + tombol "Coba lagi" (docs/UI-KuotaPlus.md, prinsip 3). Tanpa maskot: error itu serius.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 32),
            const SizedBox(height: 12),
            Text(errorMessage(error), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

/// Label status dengan latar tint. Warna selalu disertai teks, tidak pernah sendirian (docs/UI-KuotaPlus.md).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.containerOf(color), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Mengecil sedikit saat ditekan (umpan balik sentuh). Bungkus kartu yang punya InkWell/onTap sendiri.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (widget.enabled && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.of(context, Motion.press),
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Angka yang menghitung naik dari nilai sebelumnya saat data dimuat atau diperbarui.
class CountUpText extends StatelessWidget {
  const CountUpText({super.key, required this.value, required this.format, this.style});

  final int value;
  final String Function(int value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: Motion.of(context, Motion.countUp),
        curve: Motion.enterCurve,
        builder: (context, v, _) => Text(format(v.round()), style: style),
      ),
    );
  }
}

/// Blok abu-abu seukuran nilai asli, dipakai saat memuat. Sengaja diam (tanpa shimmer).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.neutralContainer, borderRadius: BorderRadius.circular(6)),
    );
  }
}

/// Daftar kartu kerangka untuk layar yang sedang memuat pertama kali.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat',
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 96, height: 16),
                SizedBox(height: 12),
                SkeletonBox(width: 160, height: 36),
                SizedBox(height: 12),
                SkeletonBox(width: double.infinity, height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state layar penuh: maskot kecil + satu kalimat + satu tombol.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.mood = MascotMood.rest,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final MascotMood mood;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mascot(mood: mood, size: 88),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Tab geser dengan penanda yang meluncur (kartu utama beranda).
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({super.key, required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.enter);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE9ECF2), borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(labels.length == 1 ? 0 : -1 + 2 * selected / (labels.length - 1), 0),
            duration: duration,
            curve: Motion.enterCurve,
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x1A0F1E50), blurRadius: 8, offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, label) in labels.indexed)
                Expanded(
                  child: Semantics(
                    selected: i == selected,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: i == selected
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: i == selected ? AppColors.text : AppColors.textMuted,
                          ),
                          child: Text(label),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Muncul sekali dengan naik dan memudar; [index] memberi jeda bertahap antar blok.
class EnterAnimation extends StatelessWidget {
  const EnterAnimation({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const _step = Duration(milliseconds: 60);

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = _step * index;
    final total = Motion.enter + delay;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Motion.enterCurve),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
    );
  }
}

/// Tinggi yang berubah mulus saat isi dibuka/ditutup. Saat "kurangi animasi" aktif ukurannya langsung melompat:
/// AnimatedSize berdurasi nol melempar assertion layout, jadi jangan memberi AnimatedSize durasi dari Motion.of.
class SmoothSize extends StatelessWidget {
  const SmoothSize({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSize(
      duration: Motion.enter,
      curve: Motion.enterCurve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
