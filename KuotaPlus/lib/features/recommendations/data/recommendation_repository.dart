import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/models/quota_package.dart';

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.rank,
    required this.package,
    required this.cost30d,
    required this.saving30d,
    required this.leftoverBytes,
    required this.reason,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) => RecommendationItem(
        id: json['id'] as int,
        rank: json['rank'] as int,
        package: QuotaPackage.fromJson(json['package'] as Map<String, dynamic>),
        cost30d: json['cost_30d'] as int,
        saving30d: json['saving_30d'] as int?,
        leftoverBytes: json['leftover_bytes'] as int,
        reason: json['reason'] as String,
      );

  final int id;
  final int rank;
  final QuotaPackage package;
  final int cost30d;

  /// Belanja paket 30 hari terakhir − cost30d. Negatif = lebih mahal; null = belum pernah beli paket (FR-10.5).
  final int? saving30d;
  final int leftoverBytes;
  final String reason;
}

/// `GET /recommendations` (FR-10).
class Recommendations {
  const Recommendations({required this.status, required this.needBytes, required this.spent30d, required this.items});

  factory Recommendations.fromJson(Map<String, dynamic> json) => Recommendations(
        status: json['status'] as String,
        needBytes: json['need']?['total_bytes'] as int?,
        spent30d: json['spent_30d'] as int?,
        items: [for (final i in json['items'] as List) RecommendationItem.fromJson(i as Map<String, dynamic>)],
      );

  /// ok | insufficient_data | already_cheapest
  final String status;
  final int? needBytes;
  final int? spent30d;
  final List<RecommendationItem> items;
}

class RecommendationRepository {
  RecommendationRepository(this._api);

  final ApiClient _api;

  Future<Recommendations> current() async {
    final body = await _api.get('/recommendations');
    return Recommendations.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// FR-10.8: event "diklik". Gagal dicatat tidak menghalangi pembelian.
  Future<void> click(int id) async {
    try {
      await _api.post('/recommendations/$id/click');
    } on ApiException {
      // Hanya untuk metrik; pengguna tetap lanjut ke checkout.
    }
  }
}
