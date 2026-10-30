import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models/alert.dart';
import '../../core/session.dart';
import 'data/home_repository.dart';

final homeRepositoryProvider = Provider((ref) => HomeRepository(ref.watch(apiClientProvider)));

/// autoDispose: dibuang saat keluar akun (layar beranda ditutup), jadi akun berikutnya memuat datanya sendiri.
final homeProvider = FutureProvider.autoDispose<HomeSnapshot>((ref) => ref.watch(homeRepositoryProvider).fetch());

/// Alert yang tampil sebagai banner di beranda web (FR-13.2). Bertahan selama sesi sampai ditutup,
/// karena server hanya mengirim setiap alert sekali; dikosongkan saat keluar akun.
final alertInboxProvider = NotifierProvider<AlertInbox, List<Alert>>(AlertInbox.new);

class AlertInbox extends Notifier<List<Alert>> {
  @override
  List<Alert> build() {
    ref.watch(authProvider);
    return const [];
  }

  void add(List<Alert> alerts) {
    final known = {for (final a in state) a.id};
    state = [...state, ...alerts.where((a) => !known.contains(a.id))];
  }

  void dismiss(int id) => state = [for (final a in state) if (a.id != id) a];
}
