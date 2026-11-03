import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'data/recommendation_repository.dart';

final recommendationRepositoryProvider = Provider((ref) => RecommendationRepository(ref.watch(apiClientProvider)));

final recommendationsProvider =
    FutureProvider.autoDispose((ref) => ref.watch(recommendationRepositoryProvider).current());
