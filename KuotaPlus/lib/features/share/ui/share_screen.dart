import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/mascot.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/api_exception.dart';
import '../../../core/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/ui/otp_screen.dart';
import '../../home/providers.dart';
import '../../rewards/providers.dart';
import '../data/share_repository.dart';
import '../providers.dart';

/// S17–S20 Bagi kuota (FR-14): nomor → jumlah + ringkasan → OTP → selesai, satu layar berlangkah supaya
/// pilihan dan Idempotency-Key bertahan. Tombol kembali mundur satu langkah.
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

enum _Step { recipient, amount, otp, done }

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _msisdn = TextEditingController();
  final _code = TextEditingController();

  _Step _step = _Step.recipient;
  ShareQuote? _quote;
  ShareOption? _option;
  OtpChallenge? _otp;
  QuotaTransfer? _result;

  /// Satu key per niat berbagi; percobaan ulang setelah jaringan putus memakai key yang sama (FR-14.11).
  String? _idempotencyKey;
  Timer? _ticker;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _msisdn.addListener(() => setState(() {}));
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _msisdn.dispose();
    _code.dispose();
    super.dispose();
  }

  ShareRepository get _repo => ref.read(shareRepositoryProvider);

  void _go(_Step step) => setState(() {
    _step = step;
    _error = null;
  });

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchQuote() => _run(() async {
    try {
      final quote = await _repo.quote(_msisdn.text);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        // Pilihan sebelumnya dipertahankan hanya jika masih boleh.
        _option = quote.options.where((o) => o.allowed && o.bytes == _option?.bytes).firstOrNull;
      });
      _go(_Step.amount);
    } on ApiException catch (e) {
      setState(() => _error = e.errors['recipient_msisdn']?.first ?? e.message);
    }
  });

  void _pick(ShareOption option) {
    HapticFeedback.selectionClick();
    setState(() {
      _option = option;
      _idempotencyKey = null; // jumlah berubah = niat baru
    });
  }

  Future<void> _requestOtp() => _run(() async {
    try {
      final otp = await _repo.requestOtp(_msisdn.text, _option!.bytes);
      if (!mounted) return;
      _idempotencyKey ??= const Uuid().v4();
      _code.clear();
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      setState(() => _otp = otp);
      _go(_Step.otp);
    } on ApiException catch (e) {
      _snack(e.message);
      if (e.code == 'SHARE_NOT_ALLOWED') await _refreshQuote();
    }
  });

  Future<void> _execute() => _run(() async {
    try {
      final result = await _repo.execute(
        recipientMsisdn: _msisdn.text,
        bytes: _option!.bytes,
        otpCode: _code.text,
        idempotencyKey: _idempotencyKey!,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref
        ..invalidate(homeProvider)
        ..invalidate(pointsProvider)
        ..invalidate(shareHistoryProvider);
      _ticker?.cancel();
      setState(() => _result = result);
      _go(_Step.done);
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'OTP_LOCKED' || 'SHARE_NOT_ALLOWED':
          // Aturan berubah (sync atau transfer lain) atau OTP terkunci: kembali ke pilihan jumlah.
          _snack(e.message);
          await _refreshQuote();
          _go(_Step.amount);
        default:
          _code.clear();
          setState(() => _error = e.message);
      }
    }
  });

  Future<void> _refreshQuote() async {
    try {
      final quote = await _repo.quote(_msisdn.text);
      if (mounted) {
        setState(() {
          _quote = quote;
          _option = null;
          _idempotencyKey = null;
        });
      }
    } on ApiException {
      // Tetap memakai quote lama; pengguna bisa mundur dan mencoba lagi.
    }
  }

  void _back() => switch (_step) {
    _Step.amount => _go(_Step.recipient),
    _Step.otp => _go(_Step.amount),
    _ => context.pop(),
  };

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      _Step.recipient => _RecipientStep(controller: _msisdn, loading: _loading, error: _error, onNext: _fetchQuote),
      _Step.amount => _AmountStep(
        quote: _quote!,
        selected: _option,
        loading: _loading,
        onPick: _pick,
        onNext: _requestOtp,
      ),
      _Step.otp => _OtpStep(
        quote: _quote!,
        option: _option!,
        otp: _otp!,
        controller: _code,
        loading: _loading,
        error: _error,
        onSubmit: _execute,
        onResend: _requestOtp,
      ),
      _Step.done => _DoneStep(result: _result!),
    };

    return PopScope(
      canPop: _step == _Step.recipient || _step == _Step.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bagi kuota'),
          automaticallyImplyLeading: _step != _Step.done,
          bottom: _step == _Step.done
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: _StepBar(index: _step.index, count: 3),
                ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.enter),
            switchInCurve: Motion.enterCurve,
            switchOutCurve: Motion.exitCurve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_step), child: body),
          ),
        ),
      ),
    );
  }
}

/// Penanda langkah 1–3 di bawah AppBar.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Langkah ${index + 1} dari $count',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.enter),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= index ? AppColors.primary : AppColors.neutralContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// S17: nomor penerima.
class _RecipientStep extends StatelessWidget {
  const _RecipientStep({required this.controller, required this.loading, required this.error, required this.onNext});

  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = [
      (Icons.data_usage_rounded, 'Hanya kuota utama dari paketmu sendiri yang bisa dibagikan.'),
      (Icons.stars_outlined, 'Berbagi memakai poin hemat.'),
      (Icons.lock_clock_outlined, 'Kuota yang sudah terkirim tidak bisa ditarik kembali.'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ke nomor siapa?', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          'Penerima harus nomor Nusantel yang aktif.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          enabled: !loading,
          autofocus: true,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.text.isEmpty ? null : onNext(),
          decoration: InputDecoration(
            labelText: 'Nomor penerima',
            hintText: '0881-0000-0007',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: error,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading || controller.text.isEmpty ? null : onNext,
          child: loading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Lanjut'),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              for (final (i, (icon, text)) in rules.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// S18: pilihan jumlah + ringkasan.
class _AmountStep extends StatelessWidget {
  const _AmountStep({
    required this.quote,
    required this.selected,
    required this.loading,
    required this.onPick,
    required this.onNext,
  });

  final ShareQuote quote;
  final ShareOption? selected;
  final bool loading;
  final ValueChanged<ShareOption> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Penerima', style: muted),
                  Text(q.recipientMasked, style: secondaryNumber.copyWith(fontSize: 20)),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 60),
          child: Text(
            q.recipientHasAccount
                ? 'Memakai Kuota+, akan dapat notifikasi.'
                : 'Belum memakai Kuota+, diberi tahu lewat SMS.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w400),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sisa jatah berbagi 30 hari',
                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatGb(q.remainingBytes), style: secondaryNumber),
                  const SizedBox(width: 6),
                  Text('dari ${formatGb(q.limitBytes)}', style: muted),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: q.limitBytes == 0 ? 0 : q.remainingBytes / q.limitBytes,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: AppColors.surface,
                semanticsLabel: 'Sisa jatah berbagi ${formatGb(q.remainingBytes)} dari ${formatGb(q.limitBytes)}',
              ),
              const SizedBox(height: 8),
              Text(
                [
                  'Poinmu ${q.pointsBalance}',
                  if (q.recoversAt != null && q.usedBytes > 0) 'jatah pulih ${formatDate(q.recoversAt!)}',
                ].join(' · '),
                style: muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Pilih jumlah', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in q.options)
                SizedBox(
                  width: (box.maxWidth - 10) / 2,
                  child: _AmountTile(
                    option: option,
                    selected: option.bytes == selected?.bytes,
                    onTap: () => onPick(option),
                  ),
                ),
            ],
          ),
        ),
        SmoothSize(
          child: selected == null ? const SizedBox(width: double.infinity) : _Summary(quote: q, option: selected!),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading || selected == null ? null : onNext,
          child: loading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kirim kode OTP'),
        ),
      ],
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({required this.option, required this.selected, required this.onTap});

  final ShareOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = option;
    final duration = Motion.of(context, Motion.fade);

    return Semantics(
      button: true,
      selected: selected,
      enabled: o.allowed,
      label: '${formatGb(o.bytes)}, ${o.pointsCost} poin${o.allowed ? '' : '. Tidak tersedia: ${o.reason}'}',
      excludeSemantics: true,
      child: PressScale(
        enabled: o.allowed,
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: !o.allowed
                ? AppColors.neutralContainer
                : (selected ? AppColors.primaryContainer : AppColors.surface),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: o.allowed ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatGb(o.bytes),
                          style: secondaryNumber.copyWith(
                            fontSize: 20,
                            color: o.allowed ? AppColors.text : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                    ],
                  ),
                  Text('${o.pointsCost} poin', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                  if (!o.allowed && o.reason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      o.reason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.quote, required this.option});

  final ShareQuote quote;
  final ShareOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      ('Penerima', quote.recipientMasked),
      ('Jumlah', formatGb(option.bytes)),
      ('Poin dipakai', '${option.pointsCost} dari ${quote.pointsBalance} poin'),
      ('Berlaku di penerima s.d.', formatDateTime(option.recipientExpiresAt!)),
      ('Sisa kuota utamamu', formatBytes(option.senderRemainingAfter!)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ringkasan', style: theme.textTheme.titleMedium),
              for (final (label, value) in rows) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                    ),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Berbagi kuota tidak bisa dibatalkan setelah dikonfirmasi.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S19: OTP ke nomor pengirim, lalu eksekusi. Tanpa maskot: ini alur yang memindahkan kuota dan poin.
class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.quote,
    required this.option,
    required this.otp,
    required this.controller,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onResend,
  });

  final ShareQuote quote;
  final ShareOption option;
  final OtpChallenge otp;
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = otp.resendAvailableAt.difference(DateTime.now());
    final resendIn = left.isNegative ? Duration.zero : left;
    final demo = otp.demoOtp;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Konfirmasi dengan OTP', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          'Masukkan 6 digit kode yang dikirim ke nomormu untuk membagikan ${formatGb(option.bytes)} '
          'ke ${quote.recipientMasked}.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        if (demo != null) ...[
          const SizedBox(height: 16),
          DemoOtpBanner(
            code: demo,
            onFill: loading
                ? null
                : () {
                    controller.text = demo;
                    onSubmit();
                  },
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          enabled: !loading,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 12),
          onChanged: (value) {
            if (value.length == 6) onSubmit();
          },
          decoration: InputDecoration(labelText: 'Kode OTP', counterText: '', errorText: error, errorMaxLines: 3),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: resendIn > Duration.zero
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Kirim ulang dalam ${resendIn.inMinutes}:${(resendIn.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                )
              : TextButton(onPressed: loading ? null : onResend, child: const Text('Kirim ulang kode')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: loading || controller.text.length != 6 ? null : onSubmit,
          child: loading
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Bagikan ${formatGb(option.bytes)}'),
        ),
      ],
    );
  }
}

/// S20: selesai. Kuo ikut merayakan sekali, seperti pembayaran berhasil.
class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.result});

  final QuotaTransfer result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        const Center(child: Mascot(mood: MascotMood.celebrate, size: 120)),
        const SizedBox(height: 12),
        Text(
          'Kuota terkirim!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatGb(r.bytes)} untuk ${r.recipientMasked}, berlaku sampai ${formatDateTime(r.recipientExpiresAt)}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row(theme, 'Poin terpakai', '${r.pointsSpent} poin'),
                if (r.senderRemainingAfter != null) ...[
                  const SizedBox(height: 10),
                  _row(theme, 'Sisa kuota utamamu', formatBytes(r.senderRemainingAfter!)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => context.go('/home'), child: const Text('Selesai')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => context.go('/history?tab=berbagi'), child: const Text('Lihat riwayat berbagi')),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      ),
      Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
    ],
  );
}
