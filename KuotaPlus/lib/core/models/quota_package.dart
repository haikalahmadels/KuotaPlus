/// Objek `Package`: item katalog (docs/API-KuotaPlus.md).
class QuotaPackage {
  const QuotaPackage({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.price,
    required this.mainQuota,
    required this.appQuota,
    required this.appCategory,
    required this.appExamples,
    required this.validityDays,
    required this.isRecommended,
  });

  factory QuotaPackage.fromJson(Map<String, dynamic> json) => QuotaPackage(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        price: json['price'] as int,
        mainQuota: json['main_quota'] as int,
        appQuota: json['app_quota'] as int,
        appCategory: json['app_category'] as String?,
        appExamples: (json['app_examples'] as List).cast<String>(),
        validityDays: json['validity_days'] as int,
        isRecommended: json['is_recommended'] as bool,
      );

  final int id;
  final String code;
  final String name;

  /// harian | mingguan | bulanan | aplikasi
  final String type;
  final int price;
  final int mainQuota;
  final int appQuota;
  final String? appCategory;
  final List<String> appExamples;
  final int validityDays;
  final bool isRecommended;
}

/// Label tampilan untuk kategori kuota aplikasi dan tipe paket.
const categoryLabels = {'video': 'Video', 'sosmed': 'Sosmed', 'game': 'Game', 'belajar': 'Belajar'};
const packageTypeLabels = {'harian': 'Harian', 'mingguan': 'Mingguan', 'bulanan': 'Bulanan', 'aplikasi': 'Aplikasi'};
