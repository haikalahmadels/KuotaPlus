import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/models/subscriber.dart';
import '../../../core/models/subscription.dart';

/// Isi `GET /home` yang dipakai di M2. Prediksi, rekomendasi, dan alert ditambahkan di M5–M7.
class HomeData {
  const HomeData({
    required this.serverTime,
    required this.subscriber,
    required this.subscriptions,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
        serverTime: DateTime.parse(json['server_time'] as String),
        subscriber: Subscriber.fromJson(json['subscriber'] as Map<String, dynamic>),
        subscriptions: [
          for (final s in json['subscriptions'] as List) Subscription.fromJson(s as Map<String, dynamic>),
        ],
      );

  final DateTime serverTime;
  final Subscriber subscriber;
  final List<Subscription> subscriptions;
}

class HomeSnapshot {
  const HomeSnapshot(this.data, {required this.fromCache});

  final HomeData data;

  /// True saat server tidak terjangkau dan yang tampil adalah respons terakhir (FR-2.5).
  final bool fromCache;
}

class HomeRepository {
  HomeRepository(this._api);

  static const _cacheKey = 'home_cache';

  final ApiClient _api;

  Future<HomeSnapshot> fetch() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final body = await _api.get('/home') as Map<String, dynamic>;
      await prefs.setString(_cacheKey, jsonEncode(body['data']));
      return HomeSnapshot(HomeData.fromJson(body['data'] as Map<String, dynamic>), fromCache: false);
    } on ApiException catch (e) {
      final cached = prefs.getString(_cacheKey);
      if (!e.isNetwork || cached == null) rethrow;
      return HomeSnapshot(HomeData.fromJson(jsonDecode(cached) as Map<String, dynamic>), fromCache: true);
    }
  }
}
