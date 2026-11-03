import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/mascot.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../packages/providers.dart';
import '../data/rewards_repository.dart';
import '../providers.dart';

/// S15 (FR-11.7), tata letak mockup "Reward" M10: saldo + streak, pintasan, poin kedaluwarsa, kalender 30 hari,
/// dan poin terbaru.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (points) {
          AsyncData(:final value) => RefreshIndicator(
              onRefresh: () {
                ref.invalidate(ledgerProvider);
                return ref.refresh(pointsProvider.future);
              },
              child: _Content(value),
            ),
          AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(pointsProvider)),
          _ => const SkeletonCardList(),
        },
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content(this.points);

  final PointsSummary points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = points;
    final rupiahPerPoint = ref.watch(packagesProvider).value?.points.rupiahPerPoint;

    final blocks = <Widget>[
      _BalanceCard(points: p, rupiahPerPoint: rupiahPerPoint),
      Row(
        children: [
          Expanded(
            child: _Shortcut(
              icon: Icons.sell_outlined,
              ink: AppColors.primary,
              tint: AppColors.primaryContainer,
              title: 'Tukar jadi diskon',
              body: 'Saat membeli paket',
              onTap: () => context.go('/packages'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Shortcut(
              icon: Icons.ios_share_rounded,
              ink: AppColors.violet,
              tint: AppColors.violetContainer,
              title: 'Bagi kuota',
              body: 'Memakai poin hemat',
              onTap: () => context.push('/share'),
            ),
          ),
        ],
      ),
      // Nada informatif, bukan tekanan "tukar sekarang" (docs/RISET-UI-Provider.md).
      if (p.expiringPoints != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.neutralContainer, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${p.expiringPoints} poin kedaluwarsa mulai ${formatDate(p.firstExpiresAt!)}.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      _Calendar(points: p),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cara dapat poin', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Pakai data di bawah jatah harianmu (minimal ${formatBytes(p.minUsageBytes)}) untuk +${p.pointsPerDay} poin. '
                'Setiap ${p.streakLength} hari hemat berturut-turut dapat bonus +${p.streakBonus} poin. '
                'Poin bisa ditukar jadi diskon paket atau dipakai untuk berbagi kuota.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
      const _RecentLedger(),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hemat kuota, dapat poin', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                  Text('Reward', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24, height: 32 / 24)),
                ],
              ),
            ),
            OutlinedButton(onPressed: () => context.push('/rewards/ledger'), child: const Text('Riwayat poin')),
          ],
        ),
        const SizedBox(height: 14),
        for (final (i, block) in blocks.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: EnterAnimation(index: i, child: block),
          ),
      ],
    );
  }
}

/// Saldo + cincin streak dengan Kuo. Kuo merayakan (confetti) sekali per hari jika kemarin hari hemat,
/// yaitu saat poin baru benar-benar masuk (docs/UI-KuotaPlus.md, Maskot).
class _BalanceCard extends StatefulWidget {
  const _BalanceCard({required this.points, required this.rupiahPerPoint});

  final PointsSummary points;
  final int? rupiahPerPoint;

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    _maybeCelebrate();
  }

  Future<void> _maybeCelebrate() async {
    final days = [...widget.points.calendar]..sort((a, b) => a.date.compareTo(b.date));
    if (days.isEmpty || days.last.result != 'hemat' || days.last.points <= 0) return;
    final key = 'reward_celebrated_${DateFormat('yyyy-MM-dd').format(toWib(days.last.date))}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _celebrate = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.points;
    final len = p.streakLength;
    // Posisi dalam siklus bonus: streak 7 dari 7 = penuh, lalu mulai lagi.
    final inCycle = p.streak == 0 ? 0 : (p.streak % len == 0 ? len : p.streak % len);
    final left = len - inCycle;
    final lastDay = p.calendar.isEmpty ? null : ([...p.calendar]..sort((a, b) => a.date.compareTo(b.date))).last;
    final broke = p.streak == 0 && lastDay?.result == 'boros';
    final mood = _celebrate ? MascotMood.celebrate : (broke ? MascotMood.rest : MascotMood.wave);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.hero)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 132,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Semantics(
                      label: 'Streak $inCycle dari $len hari menuju bonus ${p.streakBonus} poin',
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: inCycle / len),
                        duration: Motion.of(context, Motion.countUp * 1.5),
                        curve: Motion.enterCurve,
                        builder: (context, v, _) => CustomPaint(size: const Size.square(132), painter: _RingPainter(v)),
                      ),
                    ),
                    Mascot(mood: mood, size: 84),
                    if (_celebrate) const Positioned.fill(child: IgnorePointer(child: _Confetti())),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Poin hemat', style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    )),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CountUpText(value: p.balance, format: (v) => '$v', style: displayNumber.copyWith(fontSize: 40)),
                    ),
                    if (widget.rupiahPerPoint != null)
                      Text(
                        'bernilai ${formatRupiah(p.balance * widget.rupiahPerPoint!)} diskon',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                      ),
                    if (p.held > 0)
                      Text('${p.held} poin ditahan transaksi yang belum dibayar', style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        p.streak > 0 ? '${p.streak} hari beruntun' : 'Mulai lagi hari ini',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_celebrate) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '+${lastDay?.points ?? p.pointsPerDay} poin! Kemarin kamu hemat.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Bonus $len hari beruntun', style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                    Text(
                      left == 0 ? 'Bonus didapat · +${p.streakBonus} poin' : '$left hari lagi · +${p.streakBonus} poin',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < len; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: Motion.of(context, Motion.enter) + Durations.short1 * i,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < inCycle ? AppColors.primary : const Color(0xFFE9ECF2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = AppColors.surface);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Confetti sekali, ≤ 1,2 detik dan 16 partikel (docs/UI-KuotaPlus.md, Motion). Tidak tampil saat "kurangi animasi".
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    return RepaintBoundary(
      child: AnimatedBuilder(animation: _c, builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_c.value))),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const _colors = [AppColors.primary, AppColors.violet, AppColors.sky, Color(0xFF93AEF5)];

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 16; i++) {
      final angle = i / 16 * math.pi * 2;
      final distance = (56 + (i % 4) * 16) * eased;
      final offset = center + Offset(math.cos(angle) * distance, math.sin(angle) * distance - 20 * eased);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(t * math.pi * 3 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -6, 8, 12), const Radius.circular(2)),
        Paint()..color = _colors[i % _colors.length].withValues(alpha: 1 - t),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.ink,
    required this.tint,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color ink;
  final Color tint;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressScale(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: ink, size: 20),
                ),
                const SizedBox(height: 8),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(body, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status tidak pernah lewat warna saja: setiap sel punya ikon, legenda, dan label pembaca layar.
const _resultStyles = {
  'hemat': (AppColors.primary, AppColors.onPrimary, Icons.check_rounded, 'hemat'),
  'boros': (AppColors.dangerContainer, AppColors.danger, Icons.close_rounded, 'lewat jatah'),
  'no_data': (AppColors.neutralContainer, AppColors.textMuted, Icons.remove_rounded, 'tidak ada data'),
};

/// Kalender 30 hari (Sen–Min). Ketuk hari untuk catatannya.
class _Calendar extends StatefulWidget {
  const _Calendar({required this.points});

  final PointsSummary points;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  int? _selected;

  static final _day = DateFormat('EEEE, d MMM', 'id_ID');

  String _note(CalendarDay d) => '${_day.format(toWib(d.date))}: ${switch (d.result) {
        'hemat' => 'pemakaian di bawah jatah · +${d.points} poin',
        'boros' => 'lewat jatah, tidak dapat poin',
        _ => 'tidak ada data pemakaian, streak tidak putus',
      }}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = [...widget.points.calendar]..sort((a, b) => a.date.compareTo(b.date));
    if (days.isEmpty) return const SizedBox.shrink();
    final selected = _selected ?? days.length - 1;
    final lead = toWib(days.first.date).weekday - 1; // Senin = kolom pertama
    final hemat = days.where((d) => d.result == 'hemat').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('30 hari terakhir', style: theme.textTheme.titleMedium)),
                Text('$hemat hari hemat', style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                )),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final w in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                  Center(
                    child: Text(w, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: AppColors.textMuted)),
                  ),
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (final (i, d) in days.indexed) _cell(context, d, i, i == selected),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fade),
              child: Container(
                key: ValueKey(selected),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                child: Text(_note(days[selected]), style: theme.textTheme.bodyMedium),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final MapEntry(value: (bg, ink, icon, label)) in _resultStyles.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
                        child: Icon(icon, size: 12, color: ink),
                      ),
                      const SizedBox(width: 6),
                      Text(label[0].toUpperCase() + label.substring(1), style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      )),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, CalendarDay d, int index, bool selected) {
    final (bg, ink, icon, label) = _resultStyles[d.result] ?? _resultStyles['no_data']!;
    final duration = Motion.of(context, Motion.fade);

    return Semantics(
      button: true,
      selected: selected,
      label: '${formatDate(d.date)}: $label${d.points > 0 ? ', ${d.points} poin' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selected = index);
        },
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? const [BoxShadow(color: MascotColors.light, spreadRadius: 3)] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${toWib(d.date).day}', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
              )),
              Icon(icon, size: 12, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empat entri poin terbaru; selengkapnya di Riwayat poin.
class _RecentLedger extends ConsumerWidget {
  const _RecentLedger();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(ledgerProvider).value?.items.take(4).toList() ?? [];
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            for (final (i, e) in items.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.description, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(formatDate(e.createdAt), style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w400,
                          )),
                        ],
                      ),
                    ),
                    Text(
                      e.delta > 0 ? '+${e.delta}' : '−${-e.delta}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: e.delta > 0 ? AppColors.success : AppColors.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
