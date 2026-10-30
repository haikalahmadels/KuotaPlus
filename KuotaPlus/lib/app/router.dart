import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/otp_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../core/models/quota_package.dart';
import '../features/packages/ui/checkout_screen.dart';
import '../features/packages/ui/packages_screen.dart';
import '../features/packages/ui/topup_screen.dart';
import '../features/recommendations/ui/recommendations_screen.dart';
import '../features/rewards/ui/ledger_screen.dart';
import '../features/rewards/ui/rewards_screen.dart';
import '../features/share/ui/share_screen.dart';
import '../features/transactions/ui/history_screen.dart';
import '../features/transactions/ui/payment_screen.dart';
import '../features/transactions/ui/transaction_detail_screen.dart';
import '../features/usage/ui/analysis_screen.dart';
import '../features/usage/ui/app_usage_screen.dart';
import '../features/usage/ui/usage_access_screen.dart';
import 'shell.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          _tab('/home', const HomeScreen()),
          _tab('/packages', const PackagesScreen()),
          _tab('/usage', const AnalysisScreen()),
          _tab('/rewards', const RewardsScreen()),
          _tab('/history', const HistoryScreen()),
        ],
      ),
      // Di luar shell: tampil penuh tanpa NavigationBar, dengan tombol kembali.
      GoRoute(path: '/topup', builder: (context, state) => const TopupScreen()),
      GoRoute(
        path: '/packages/:id/checkout',
        // Data paket dibawa dari katalog atau rekomendasi (paket, id rekomendasi);
        // saat halaman web di-refresh data itu hilang, jadi kembali ke katalog.
        redirect: (context, state) => state.extra is QuotaPackage || state.extra is (QuotaPackage, int) ? null : '/packages',
        builder: (context, state) => switch (state.extra) {
          (QuotaPackage package, int recommendationId) =>
            CheckoutScreen(package: package, recommendationId: recommendationId),
          final extra => CheckoutScreen(package: extra! as QuotaPackage),
        },
      ),
      GoRoute(
        path: '/payment/:id',
        builder: (context, state) => PaymentScreen(transactionId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/usage/apps/:id',
        builder: (context, state) => AppUsageScreen(
          appId: int.parse(state.pathParameters['id']!),
          period: state.uri.queryParameters['period'] ?? '7d',
        ),
      ),
      GoRoute(path: '/onboarding/usage-access', builder: (context, state) => const UsageAccessScreen()),
      GoRoute(path: '/recommendations', builder: (context, state) => const RecommendationsScreen()),
      GoRoute(path: '/rewards/ledger', builder: (context, state) => const LedgerScreen()),
      GoRoute(path: '/share', builder: (context, state) => const ShareScreen()),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) => TransactionDetailScreen(transactionId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
});

const _tabRoots = {'/home', '/packages', '/usage', '/rewards', '/history'};

/// Deep link alert (FR-13.3): tab dibuka dengan go; layar lain ditumpuk supaya ada tombol kembali.
/// Belum login → redirect ke login lalu kembali ke target.
void openAlertTarget(GoRouter router, String target) =>
    _tabRoots.contains(target) ? router.go(target) : router.push(target);

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (context, state) => screen)],
    );

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
