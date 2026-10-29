import '../../../core/api_client.dart';
import '../../../core/models/quota_package.dart';

class PackageGroup {
  const PackageGroup(this.type, this.packages);

  final String type;
  final List<QuotaPackage> packages;
}

/// Aturan tukar poin dari `settings` (FR-12.2, FR-12.4), dipakai checkout untuk menghitung batas.
/// Server tetap memvalidasi ulang (POINTS_INVALID).
class PointRules {
  const PointRules({
    required this.balance,
    required this.rupiahPerPoint,
    required this.redeemStep,
    required this.maxDiscountPercent,
    required this.minNetAmount,
  });

  factory PointRules.fromJson(Map<String, dynamic> json) => PointRules(
        balance: json['balance'] as int,
        rupiahPerPoint: json['rupiah_per_point'] as int,
        redeemStep: json['redeem_step'] as int,
        maxDiscountPercent: json['max_discount_percent'] as int,
        minNetAmount: json['min_net_amount'] as int,
      );

  final int balance;
  final int rupiahPerPoint;
  final int redeemStep;
  final int maxDiscountPercent;
  final int minNetAmount;

  /// Kelipatan redeemStep terbesar yang ≤ saldo, ≤ batas persen harga, dan menyisakan total ≥ minimal.
  int maxPointsFor(int price) {
    final byPercent = price * maxDiscountPercent ~/ 100 ~/ rupiahPerPoint;
    final byMinNet = (price - minNetAmount).clamp(0, price) ~/ rupiahPerPoint;
    final limit = [balance, byPercent, byMinNet].reduce((a, b) => a < b ? a : b);
    return limit ~/ redeemStep * redeemStep;
  }
}

class Catalog {
  const Catalog(this.groups, this.points);

  final List<PackageGroup> groups;
  final PointRules points;
}

class TopupOption {
  const TopupOption({required this.amount, required this.extendDays});

  final int amount;
  final int extendDays;
}

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<Catalog> packages() async {
    final body = await _api.get('/packages') as Map<String, dynamic>;
    return Catalog(
      [
        for (final group in body['data']['groups'] as List)
          PackageGroup(group['type'] as String, [
            for (final p in group['packages'] as List) QuotaPackage.fromJson(p as Map<String, dynamic>),
          ]),
      ],
      PointRules.fromJson(body['data']['points'] as Map<String, dynamic>),
    );
  }

  Future<List<TopupOption>> topupOptions() async {
    final body = await _api.get('/topup-options') as Map<String, dynamic>;
    return [
      for (final o in body['data'] as List)
        TopupOption(amount: o['amount'] as int, extendDays: o['extend_days'] as int),
    ];
  }
}
