import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'data/home_repository.dart';

final homeRepositoryProvider = Provider((ref) => HomeRepository(ref.watch(apiClientProvider)));

/// autoDispose: dibuang saat keluar akun (layar beranda ditutup), jadi akun berikutnya memuat datanya sendiri.
final homeProvider = FutureProvider.autoDispose<HomeSnapshot>((ref) => ref.watch(homeRepositoryProvider).fetch());
