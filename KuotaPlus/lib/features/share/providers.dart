import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'data/share_repository.dart';

final shareRepositoryProvider = Provider((ref) => ShareRepository(ref.watch(apiClientProvider)));

/// Riwayat berbagi per halaman dengan tombol "Muat lagi" (sama seperti riwayat transaksi).
final shareHistoryProvider = AsyncNotifierProvider.autoDispose<ShareHistory, QuotaTransferPage>(ShareHistory.new);

class ShareHistory extends AsyncNotifier<QuotaTransferPage> {
  int _page = 1;

  @override
  Future<QuotaTransferPage> build() {
    _page = 1;
    return ref.watch(shareRepositoryProvider).list();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) return;

    final next = await ref.read(shareRepositoryProvider).list(page: _page + 1);
    _page++;
    state = AsyncData(QuotaTransferPage([...current.items, ...next.items], hasMore: next.hasMore));
  }
}
