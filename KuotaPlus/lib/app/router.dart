import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/otp_screen.dart';
import 'home_placeholder_screen.dart';

/// Peta route lengkap ada di docs/UI-KuotaPlus.md. Route ditambahkan per milestone.
final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => signedIn.value = next);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: signedIn,
    redirect: (context, state) => authRedirect(signedIn: signedIn.value, uri: state.uri),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(from: state.uri.queryParameters['from']),
        routes: [
          GoRoute(
            path: 'otp',
            // Data challenge hilang saat halaman web di-refresh: mulai lagi dari input nomor.
            redirect: (context, state) => state.extra is OtpChallenge ? null : '/login',
            builder: (context, state) => OtpScreen(challenge: state.extra! as OtpChallenge),
          ),
        ],
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePlaceholderScreen()),
    ],
  );
});

/// Belum login → `/login?from=<asal>`. Sudah login tapi di /login → kembali ke asal atau /home.
@visibleForTesting
String? authRedirect({required bool signedIn, required Uri uri}) {
  final onLogin = uri.path == '/login' || uri.path.startsWith('/login/');

  if (!signedIn && !onLogin) {
    return Uri(path: '/login', queryParameters: {'from': uri.toString()}).toString();
  }
  if (signedIn && onLogin) {
    final from = uri.queryParameters['from'];
    // Hanya route internal, supaya parameter from tidak bisa dipakai membuka URL lain.
    return from != null && from.startsWith('/') && !from.startsWith('//') ? from : '/home';
  }
  return null;
}
