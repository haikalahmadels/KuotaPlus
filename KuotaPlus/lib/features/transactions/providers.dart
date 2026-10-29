import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models/transaction.dart';
import 'data/transaction_repository.dart';

final transactionRepositoryProvider = Provider((ref) => TransactionRepository(ref.watch(apiClientProvider)));

/// Riwayat pembelian (FR-6), dimuat per halaman dengan tombol "Muat lagi".
final transactionHistoryProvider =
    AsyncNotifierProvider.autoDispose<TransactionHistory, TransactionPage>(TransactionHistory.new);

class TransactionHistory extends AsyncNotifier<TransactionPage> {
  int _page = 1;

  @override
  Future<TransactionPage> build() {
    _page = 1;
    return ref.watch(transactionRepositoryProvider).list();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) return;

    final next = await ref.read(transactionRepositoryProvider).list(page: _page + 1);
    _page++;
    state = AsyncData(TransactionPage(<Transaction>[...current.items, ...next.items], hasMore: next.hasMore));
  }
}
