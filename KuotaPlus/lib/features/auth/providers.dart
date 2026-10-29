import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import 'data/auth_repository.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
    onSignedIn: () => ref.read(authProvider.notifier).signedIn(),
    onSignedOut: () => ref.read(authProvider.notifier).signedOut(),
  ),
);
