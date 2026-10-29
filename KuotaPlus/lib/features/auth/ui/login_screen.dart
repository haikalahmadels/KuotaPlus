import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_exception.dart';
import '../providers.dart';

/// S01 (docs/UI-KuotaPlus.md).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  /// Route asal sebelum diarahkan ke login, diteruskan ke layar OTP.
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _msisdn = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _msisdn.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _msisdn.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final challenge = await ref.read(authRepositoryProvider).requestOtp(_msisdn.text);
      if (!mounted) return;
      final query = widget.from == null ? '' : '?from=${Uri.encodeComponent(widget.from!)}';
      // Layar OTP mengembalikan pesan jika nomor terkunci.
      final message = await context.push<String>('/login/otp$query', extra: challenge);
      if (mounted && message != null) setState(() => _error = message);
    } on ApiException catch (e) {
      setState(() => _error = e.errors['msisdn']?.first ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kuota+', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Masuk dengan nomor Nusantel', style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _msisdn,
                    enabled: !_loading,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _msisdn.text.isEmpty ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Nomor HP',
                      hintText: '0881-0000-0001',
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading || _msisdn.text.isEmpty ? null : _submit,
                    child: _loading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Kirim kode OTP'),
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
