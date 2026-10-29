import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/models/forecast.dart';
import '../../../core/models/subscriber.dart';
import '../../../core/models/subscription.dart';

/// Isi `GET /home`. Alert ditambahkan di M7.
class HomeData {
  const HomeData({
    required this.serverTime,
    required this.subscriber,
    required this.subscriptions,
    this.forecast,
    this.dailyBudget,
    this.teaser,
    this.points = (balance: 0, streak: 0),
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final budget = json['daily_budget'] as Map<String, dynamic>?;
    final teaser = json['recommendation_teaser'] as Map<String, dynamic>?;

    return HomeData(
      serverTime: DateTime.parse(json['server_time'] as String),
      subscriber: Subscriber.fromJson(json['subscriber'] as Map<String, dynamic>),
      subscriptions: [
        for (final s in json['subscriptions'] as List) Subscription.fromJson(s as Map<String, dynamic>),
      ],
      forecast: json['forecast'] == null ? null : Forecast.fromJson(json['forecast'] as Map<String, dynamic>),
      dailyBudget: budget == null
          ? null
          : (budgetBytes: budget['budget_bytes'] as int, usedTodayBytes: budget['used_today_bytes'] as int),
      points: (balance: json['points']['balance'] as int, streak: json['points']['streak'] as int),
      teaser: teaser == null
          ? null
          : (
              recommendationId: teaser['recommendation_id'] as int,
              packageName: teaser['package_name'] as String,
              saving: teaser['saving_30d'] as int,
            ),
    );
  }

  final DateTime serverTime;
  final Subscriber subscriber;
  final List<Subscription> subscriptions;
  final Forecast? forecast;

  /// Jatah hari ini dan pemakaian hari ini (FR-2.3).
  final ({int budgetBytes, int usedTodayBytes})? dailyBudget;

  /// Ada hanya jika rekomendasi utama memberi penghematan (FR-2.4).
  final ({int recommendationId, String packageName, int saving})? teaser;

  /// Saldo poin dan streak hari hemat (FR-2.4).
  final ({int balance, int streak}) points;
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
