import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'data/catalog_repository.dart';

final catalogRepositoryProvider = Provider((ref) => CatalogRepository(ref.watch(apiClientProvider)));

final packagesProvider = FutureProvider.autoDispose((ref) => ref.watch(catalogRepositoryProvider).packages());

final topupOptionsProvider = FutureProvider.autoDispose((ref) => ref.watch(catalogRepositoryProvider).topupOptions());
