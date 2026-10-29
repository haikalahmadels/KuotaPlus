import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_exception.dart';
import '../../../core/format.dart';
import '../data/auth_repository.dart';
import '../providers.dart';

/// S02 (docs/UI-KuotaPlus.md). Setelah verifikasi berhasil, router yang memindahkan ke route asal.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.challenge});

  final OtpChallenge challenge;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  late OtpChallenge _challenge = widget.challenge;
  late final Timer _ticker;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    _code.dispose();
    super.dispose();
  }

  Duration get _resendIn {
    final left = _challenge.resendAvailableAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'OTP_LOCKED') {
        context.pop(e.message);
        return;
      }
      _code.clear();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _verify() => _run(() => ref.read(authRepositoryProvider).verify(_challenge.msisdn, _code.text));

  void _resend() => _run(() async {
        final challenge = await ref.read(authRepositoryProvider).requestOtp(_challenge.msisdn);
        setState(() => _challenge = challenge);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demoOtp = _challenge.demoOtp;
    final resendIn = _resendIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Masukkan 6 digit kode yang dikirim ke ${formatMsisdn(_challenge.msisdn)}',
                      style: theme.textTheme.bodyLarge),
                  if (demoOtp != null) ...[
                    const SizedBox(height: 16),
                    _DemoBanner(code: demoOtp, onFill: _loading ? null : () {
                      _code.text = demoOtp;
                      _verify();
                    }),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    enabled: !_loading,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 12),
                    onChanged: (value) {
                      if (value.length == 6) _verify();
                    },
                    decoration: InputDecoration(labelText: 'Kode OTP', counterText: '', errorText: _error),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: resendIn > Duration.zero
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Kirim ulang dalam ${resendIn.inMinutes}:${(resendIn.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : TextButton(onPressed: _loading ? null : _resend, child: const Text('Kirim ulang kode')),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading || _code.text.length != 6 ? null : _verify,
                    child: _loading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FR-1.3: OTP dummy tidak dikirim lewat SMS, jadi ditampilkan di sini.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.code, required this.onFill});

  final String code;
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MODE DEMO', style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                )),
                Text('Kode OTP: $code', style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          TextButton(onPressed: onFill, child: const Text('Isi')),
        ],
      ),
    );
  }
}
