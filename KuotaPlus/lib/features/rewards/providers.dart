import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'data/rewards_repository.dart';

final rewardsRepositoryProvider = Provider((ref) => RewardsRepository(ref.watch(apiClientProvider)));

final pointsProvider = FutureProvider.autoDispose((ref) => ref.watch(rewardsRepositoryProvider).summary());

/// Riwayat poin per halaman dengan tombol "Muat lagi" (sama seperti riwayat transaksi).
final ledgerProvider = AsyncNotifierProvider.autoDispose<Ledger, LedgerPage>(Ledger.new);

class Ledger extends AsyncNotifier<LedgerPage> {
  int _page = 1;

  @override
  Future<LedgerPage> build() {
    _page = 1;
    return ref.watch(rewardsRepositoryProvider).ledger();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) return;

    final next = await ref.read(rewardsRepositoryProvider).ledger(page: _page + 1);
    _page++;
    state = AsyncData(LedgerPage([...current.items, ...next.items], hasMore: next.hasMore));
  }
}
