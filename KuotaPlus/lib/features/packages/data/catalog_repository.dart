import '../../../core/api_client.dart';
import '../../../core/models/quota_package.dart';

class PackageGroup {
  const PackageGroup(this.type, this.packages);

  final String type;
  final List<QuotaPackage> packages;
}

class TopupOption {
  const TopupOption({required this.amount, required this.extendDays});

  final int amount;
  final int extendDays;
}

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  /// Objek `points` di respons dipakai checkout di M6.
  Future<List<PackageGroup>> packages() async {
    final body = await _api.get('/packages') as Map<String, dynamic>;
    return [
      for (final group in body['data']['groups'] as List)
        PackageGroup(group['type'] as String, [
          for (final p in group['packages'] as List) QuotaPackage.fromJson(p as Map<String, dynamic>),
        ]),
    ];
  }

  Future<List<TopupOption>> topupOptions() async {
    final body = await _api.get('/topup-options') as Map<String, dynamic>;
    return [
      for (final o in body['data'] as List)
        TopupOption(amount: o['amount'] as int, extendDays: o['extend_days'] as int),
    ];
  }
}
