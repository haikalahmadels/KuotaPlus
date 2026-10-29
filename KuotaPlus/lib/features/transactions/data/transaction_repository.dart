import '../../../core/api_client.dart';
import '../../../core/models/transaction.dart';

class TransactionPage {
  const TransactionPage(this.items, {required this.hasMore});

  final List<Transaction> items;
  final bool hasMore;
}

class TransactionRepository {
  TransactionRepository(this._api);

  final ApiClient _api;

  /// [idempotencyKey] dibuat sekali saat pengguna menekan Bayar dan dipakai ulang untuk setiap percobaan ulang.
  Future<Transaction> create({
    required String type,
    required String paymentMethod,
    required String idempotencyKey,
    int? packageId,
    int? topupAmount,
    int? recommendationId,
  }) async {
    final body = await _api.post(
      '/transactions',
      idempotencyKey: idempotencyKey,
      data: {
        'type': type,
        'payment_method': paymentMethod,
        'package_id': ?packageId,
        'topup_amount': ?topupAmount,
        'recommendation_id': ?recommendationId,
      },
    );
    return Transaction.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Transaction> get(int id) async {
    final body = await _api.get('/transactions/$id');
    return Transaction.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<TransactionPage> list({int page = 1}) async {
    final body = await _api.get('/transactions', query: {'page': page}) as Map<String, dynamic>;
    final meta = body['meta'] as Map<String, dynamic>;
    return TransactionPage(
      [for (final t in body['data'] as List) Transaction.fromJson(t as Map<String, dynamic>)],
      hasMore: (meta['current_page'] as int) < (meta['last_page'] as int),
    );
  }
}
