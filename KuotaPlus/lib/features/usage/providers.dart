import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'data/device_usage.dart';
import 'data/usage_repository.dart';

final usageRepositoryProvider = Provider((ref) => UsageRepository(ref.watch(apiClientProvider)));

/// Periode analisis yang dipilih: today | 7d | 30d.
final usagePeriodProvider = NotifierProvider<UsagePeriod, String>(UsagePeriod.new);

class UsagePeriod extends Notifier<String> {
  @override
  String build() => '7d';

  void select(String period) => state = period;
}

final usageSummaryProvider = FutureProvider.autoDispose<UsageSummary>(
  (ref) => ref.watch(usageRepositoryProvider).summary(ref.watch(usagePeriodProvider)),
);

final usageAccessProvider = FutureProvider.autoDispose<bool>((ref) => hasUsageAccess());

/// Pemakaian hari ini untuk beranda, terpisah dari periode yang dipilih di layar Analisis.
final todayUsageProvider = FutureProvider.autoDispose<UsageSummary>(
  (ref) => ref.watch(usageRepositoryProvider).summary('today'),
);
