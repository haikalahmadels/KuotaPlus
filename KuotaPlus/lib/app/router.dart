import 'package:go_router/go_router.dart';

import 'server_check_screen.dart';

/// Peta route lengkap ada di docs/UI-KuotaPlus.md. Route ditambahkan per milestone.
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ServerCheckScreen()),
  ],
);
