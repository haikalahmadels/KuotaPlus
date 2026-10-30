import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/mascot.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/models/quota_package.dart';
import '../../../core/models/subscriber.dart';
import '../../../core/models/subscription.dart';
import '../../rewards/data/rewards_repository.dart';
import '../../rewards/providers.dart';
import '../../usage/providers.dart';

/// Kartu utama beranda, tampilan "Paket aktif" (mockup G revisi): tangki berombak setinggi sisa kuota utama,
/// kuota aplikasi di bawah angka utama, lalu sisa pulsa dan masa aktif nomor di dasar kartu.
/// Ketuk kartu untuk rincian per paket.
class ActiveQuotaCard extends StatelessWidget {
  const ActiveQuotaCard({super.key, required this.subscriber, required this.subscriptions});

  final Subscriber subscriber;
  final List<Subscription> subscriptions;

  static DateTime _earliest(Iterable<Subscription> subs) =>
      subs.map((s) => s.expiresAt).reduce((a, b) => a.isBefore(b) ? a : b);

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Rincian per paket', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final s in subscriptions) _PackageDetail(s),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);
    final subs = subscriptions;
    final exhausted = subs.isNotEmpty && subs.every((s) => s.isExhausted);
    final mainTotal = subs.fold(0, (sum, s) => sum + s.mainTotal);
    final mainLeft = subs.fold(0, (sum, s) => sum + s.mainRemaining);
    final appSubs = subs.where((s) => s.appTotal > 0).toList();
    final appTotal = appSubs.fold(0, (sum, s) => sum + s.appTotal);
    final appLeft = appSubs.fold(0, (sum, s) => sum + s.appRemaining);
    final categories = appSubs.map((s) => s.appCategory).toSet();
    final appLabel =
        categories.length == 1 ? (categoryLabels[categories.first] ?? 'aplikasi').toLowerCase() : 'aplikasi';
    final ratio = mainTotal == 0 ? 0.0 : mainLeft / mainTotal;

    final info = Row(
      children: [
        Expanded(child: _InfoTile(label: 'Sisa pulsa', value: formatRupiah(subscriber.pulsaBalance))),
        const SizedBox(width: 8),
        Expanded(
          child: subscriber.inGrace
              ? _InfoTile(
                  label: 'Masa tenggang s.d.',
                  value: formatDate(subscriber.graceUntil!),
                  valueColor: AppColors.warning,
                )
              : _InfoTile(label: 'Nomor aktif s.d.', value: formatDate(subscriber.activeUntil)),
        ),
      ],
    );

    final Widget details;
    if (subs.isEmpty) {
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kamu tidak punya kuota aktif', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Pilih paket yang pas dengan pemakaianmu.', style: muted),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/packages'), child: const Text('Lihat paket')),
        ],
      );
    } else {
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Sisa kuota utama', style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                )),
              ),
              if (exhausted)
                const StatusChip(label: 'Kuota habis', color: AppColors.danger)
              else
                _Pill(child: CountUpText(value: (ratio * 100).round(), format: (v) => '$v% tersisa')),
            ],
          ),
          CountUpText(value: mainLeft, format: formatBytes, style: displayNumber.copyWith(height: 44 / 36)),
          Text(
            subs.length == 1
                ? 'dari ${formatBytes(mainTotal)} · ${subs.single.name} s.d. ${formatDate(subs.single.expiresAt)}'
                : 'dari ${formatBytes(mainTotal)} · ${subs.length} paket, paling cepat s.d. ${formatDate(_earliest(subs))}',
            style: muted,
          ),
          if (appTotal > 0) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '●  Kuota $appLabel  ',
                    style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: formatBytes(appLeft),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  TextSpan(text: ' dari ${formatBytes(appTotal)}', style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
            Text('s.d. ${formatDate(_earliest(appSubs))}', style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            )),
          ],
        ],
      );
    }

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.hero),
      child: ColoredBox(
        color: AppColors.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: details),
            // Air hanya di area bawah teks, jadi sepenuh apa pun kuotanya teks tetap terbaca.
            // Kotak pulsa menutupi ± 44% bawah area ini (air kosong = permukaan tepat di atasnya); saat penuh
            // permukaan berhenti 52 px dari atas area supaya Kuo tetap mengapung di atas air.
            SizedBox(
              height: 160,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _WaterTank(
                      level: 0.44 + ratio * 0.235,
                      mood: subs.isEmpty || exhausted ? MascotMood.sleepy : MascotMood.wave,
                    ),
                  ),
                  Positioned(left: 12, right: 12, bottom: 12, child: info),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (subs.isEmpty) return card;
    return Semantics(
      button: true,
      hint: 'Ketuk untuk rincian per paket',
      child: PressScale(child: GestureDetector(onTap: () => _showDetails(context), child: card)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
      child: DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        child: child,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          Text(value, style: secondaryNumber.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }
}

class _PackageDetail extends StatelessWidget {
  const _PackageDetail(this.subscription);

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subscription;

    Widget bar(String label, int left, int total, Color color) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label · ${formatBytes(left)} dari ${formatBytes(total)}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: total == 0 ? 0 : left / total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: color,
                backgroundColor: AppColors.neutralContainer,
                semanticsLabel: '$label ${s.name} ${formatBytes(left)} dari ${formatBytes(total)}',
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.name, style: theme.textTheme.titleMedium)),
              if (s.isExhausted) const StatusChip(label: 'Kuota habis', color: AppColors.danger),
            ],
          ),
          Text('Berakhir ${formatDateTime(s.expiresAt)}', style: theme.textTheme.bodySmall),
          bar('Utama', s.mainRemaining, s.mainTotal, AppColors.primary),
          if (s.appTotal > 0)
            bar(categoryLabels[s.appCategory] ?? 'Aplikasi', s.appRemaining, s.appTotal, AppColors.violet),
        ],
      ),
    );
  }
}

/// Latar tangki: air berombak naik ke [level] (0..1 dari dasar) dan Kuo mengapung di permukaannya.
/// Ombak diam saat "kurangi animasi" aktif.
class _WaterTank extends StatefulWidget {
  const _WaterTank({required this.level, required this.mood});

  final double level;
  final MascotMood mood;

  @override
  State<_WaterTank> createState() => _WaterTankState();
}

class _WaterTankState extends State<_WaterTank> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.level),
      duration: Motion.of(context, Motion.countUp * 2),
      curve: Motion.enterCurve,
      builder: (context, level, _) => LayoutBuilder(
        builder: (context, box) {
          final surface = box.maxHeight * (1 - level);
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) => CustomPaint(painter: _TankPainter(level: level, phase: _wave.value)),
                  ),
                ),
              ),
              Positioned(
                right: 28,
                top: (surface - 52).clamp(0.0, math.max(0.0, box.maxHeight - 68)),
                child: Mascot(mood: widget.mood, size: 64, light: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu utama, tampilan "Hari ini": tangki jatah harian (FR-2.3). Ketuk untuk penjelasan jatah.
class DailyTank extends StatefulWidget {
  const DailyTank({super.key, required this.budgetBytes, required this.usedTodayBytes});

  final int budgetBytes;
  final int usedTodayBytes;

  @override
  State<DailyTank> createState() => _DailyTankState();
}

class _DailyTankState extends State<DailyTank> {
  bool _why = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = widget.budgetBytes;
    final used = widget.usedTodayBytes;
    final over = used > budget;
    final left = over ? 0 : budget - used;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Sisa jatah hari ini ${formatBytes(left)} dari ${formatBytes(budget)}. Ketuk untuk penjelasan',
          excludeSemantics: true,
          child: PressScale(
            child: GestureDetector(
              onTap: () => setState(() => _why = !_why),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.hero),
                child: Stack(
                  children: [
                    // Air paling tinggi 55% kartu supaya teks di atas tetap terbaca.
                    Positioned.fill(
                      child: _WaterTank(
                        level: budget == 0 ? 0 : (left / budget).clamp(0.0, 1.0) * 0.55,
                        mood: over ? MascotMood.worried : MascotMood.wave,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text('Sisa jatah hari ini', style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                )),
                              ),
                              _Pill(child: Text('Kenapa ${formatBytes(budget)}?')),
                            ],
                          ),
                          CountUpText(value: left, format: formatBytes, style: displayNumber.copyWith(height: 44 / 36)),
                          Text(
                            over
                                ? 'Terpakai ${formatBytes(used)}, lewat ${formatBytes(used - budget)} dari jatah'
                                : 'dari ${formatBytes(budget)} · terpakai ${formatBytes(used)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: over ? AppColors.danger : AppColors.textMuted,
                              fontWeight: over ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.enter),
          curve: Motion.enterCurve,
          alignment: Alignment.topCenter,
          child: _why
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Jatah harian = sisa kuota utama dibagi jumlah hari sampai paketmu berakhir, dihitung tiap pukul '
                    '00.00. Selama pemakaian tidak lewat jatah, kuotamu cukup dan kamu dapat poin hemat.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _TankPainter extends CustomPainter {
  _TankPainter({required this.level, required this.phase});

  /// Tinggi air 0..1 dari dasar kartu.
  final double level;

  /// Fase ombak 0..1.
  final double phase;

  Path _wave(Size size, double shift, double amplitude) {
    final y = size.height * (1 - level);
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += 4) {
      path.lineTo(x, y + math.sin((x / size.width * 2 + shift) * math.pi * 2) * amplitude);
    }
    return path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.primaryContainer);
    if (level <= 0) return;
    canvas.drawPath(_wave(size, -phase + 0.3, 7), Paint()..color = AppColors.primary.withValues(alpha: 0.35));
    canvas.drawPath(_wave(size, phase, 6), Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_TankPainter old) => old.level != level || old.phase != phase;
}

/// Menu yang paling sering dipakai, tepat di bawah kartu utama (mockup G).
class QuickMenu extends StatelessWidget {
  const QuickMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.sell_outlined, label: 'Beli paket', onTap: () => context.go('/packages')),
      (icon: Icons.add_circle_outline_rounded, label: 'Isi ulang', onTap: () => context.push('/topup')),
      (
        icon: Icons.ios_share_rounded,
        label: 'Bagi kuota',
        // shortcut: Bagi kuota dibangun di M8; sampai itu tombol menjelaskan, bukan disembunyikan.
        onTap: () => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Bagi kuota segera hadir.'))),
      ),
      (icon: Icons.insights_outlined, label: 'Analisis', onTap: () => context.go('/usage')),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: softShadow,
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: PressScale(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(item.icon, color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(item.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _accents = [
  (ink: AppColors.primary, tint: AppColors.primaryContainer),
  (ink: AppColors.violet, tint: AppColors.violetContainer),
  (ink: AppColors.sky, tint: AppColors.skyContainer),
];

/// Tiga aplikasi paling boros hari ini. Disembunyikan jika belum ada data (mis. web atau izin belum diberikan).
class TodayApps extends ConsumerWidget {
  const TodayApps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(todayUsageProvider).value?.topApps.where((a) => a.appId != null).take(3).toList() ?? [];
    if (apps.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Dipakai untuk apa hari ini?', style: theme.textTheme.titleMedium)),
                  TextButton(onPressed: () => context.go('/usage'), child: const Text('Analisis')),
                ],
              ),
              for (final (i, app) in apps.indexed) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _accents[i].tint, borderRadius: BorderRadius.circular(12)),
                      child: ExcludeSemantics(
                        child: Text(app.label.characters.first.toUpperCase(), style: TextStyle(
                          color: _accents[i].ink,
                          fontWeight: FontWeight.w800,
                        )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(app.label, style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ))),
                              Text(formatBytes(app.bytes), style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              )),
                            ],
                          ),
                          const SizedBox(height: 5),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: app.percent / 100),
                            duration: Motion.of(context, Motion.countUp + Durations.short2 * (i + 1)),
                            curve: Motion.enterCurve,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                              color: _accents[i].ink,
                              backgroundColor: AppColors.neutralContainer,
                              semanticsLabel: '${app.label} ${formatBytes(app.bytes)}, ${app.percent.round()} persen',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rekor hemat 7 hari terakhir dari kalender poin (FR-2.4, FR-11). Ketuk hari untuk catatannya.
class WeekStreak extends ConsumerStatefulWidget {
  const WeekStreak({super.key, required this.balance, required this.streak, required this.today});

  final int balance;
  final int streak;

  /// Waktu server; tanggal hari ini diambil dalam WIB.
  final DateTime today;

  @override
  ConsumerState<WeekStreak> createState() => _WeekStreakState();
}

class _WeekStreakState extends ConsumerState<WeekStreak> {
  int? _selected;

  static final _weekday = DateFormat('E', 'id_ID');
  static final _longDay = DateFormat('EEEE, d MMM', 'id_ID');

  /// Tanggal kalender (WIB) tanpa jam, apa pun zona waktu perangkat.
  static DateTime _dayOf(DateTime time) {
    final wib = toWib(time);
    return DateTime(wib.year, wib.month, wib.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = ref.watch(pointsProvider).value;
    final today = _dayOf(widget.today);
    // 6 hari terakhir dari kalender + hari ini (hari ini baru dinilai besok pukul 00.00).
    final past = [
      for (final d in points?.calendar ?? <CalendarDay>[])
        if (_dayOf(d.date).isBefore(today)) d,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final days = [...past.skip(math.max(0, past.length - 6)), null];
    final selected = _selected ?? days.length - 1;
    final perDay = points?.pointsPerDay;

    String note(CalendarDay? d) => switch (d) {
          null => perDay == null
              ? 'Hari ini: tetap di bawah jatah untuk dapat poin.'
              : 'Hari ini: tetap di bawah jatah untuk dapat +$perDay poin.',
          CalendarDay(result: 'hemat') => '${_longDay.format(toWib(d.date))}: hemat · +${d.points} poin',
          CalendarDay(result: 'boros') => '${_longDay.format(toWib(d.date))}: lewat jatah, tidak dapat poin',
          _ => '${_longDay.format(toWib(d.date))}: tidak ada data pemakaian',
        };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.streak > 0 ? '${widget.streak} hari hemat beruntun' : 'Mulai hemat hari ini',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  ActionChip(
                    onPressed: () => context.go('/rewards'),
                    backgroundColor: AppColors.primaryContainer,
                    side: BorderSide.none,
                    label: Text('${widget.balance} poin', style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (i, d) in days.indexed)
                    Expanded(
                      child: _DayDot(
                        day: d,
                        label: d == null ? 'Ini' : _weekday.format(toWib(d.date)),
                        selected: i == selected,
                        semantics: note(d),
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fade),
                child: Container(
                  key: ValueKey(selected),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                  child: Text(note(days[selected]), style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.label,
    required this.selected,
    required this.semantics,
    required this.onTap,
  });

  /// Null = hari ini (belum dinilai).
  final CalendarDay? day;
  final String label;
  final bool selected;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Widget? icon, BoxBorder? border) = switch (day) {
      null => (AppColors.surface, null, Border.all(color: AppColors.primary, width: 2)),
      CalendarDay(result: 'hemat') => (AppColors.primary, const Icon(Icons.check_rounded, size: 18, color: AppColors.onPrimary), null),
      CalendarDay(result: 'boros') => (AppColors.dangerContainer, const Icon(Icons.close_rounded, size: 18, color: AppColors.danger), null),
      _ => (AppColors.neutralContainer, null, null),
    };
    final duration = Motion.of(context, Motion.fade);

    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: duration,
                curve: Motion.enterCurve,
                child: AnimatedContainer(
                  duration: duration,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: border,
                    boxShadow: selected ? const [BoxShadow(color: MascotColors.light, spreadRadius: 3)] : null,
                  ),
                  child: icon,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
