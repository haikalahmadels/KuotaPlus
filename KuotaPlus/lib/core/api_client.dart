import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exception.dart';
import 'config.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider((ref) => TokenStorage());

/// False setelah request gagal karena jaringan. Tombol beli dan isi ulang membaca ini untuk menonaktifkan diri.
final serverReachableProvider = NotifierProvider<ServerReachable, bool>(ServerReachable.new);

class ServerReachable extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool reachable) {
    if (state != reachable) state = reachable;
  }
}

final apiClientProvider = Provider(
  (ref) => ApiClient(
    ref.watch(tokenStorageProvider),
    onReachable: (reachable) => ref.read(serverReachableProvider.notifier).set(reachable),
  ),
);

/// HTTP client untuk `/api`. Semua error dilempar sebagai [ApiException].
/// Body sukses dikembalikan utuh (`{data, links?, meta?}`), atau null untuk 204.
class ApiClient {
  ApiClient(this._tokens, {void Function(bool reachable)? onReachable, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '$apiBaseUrl/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onResponse: (response, handler) {
        onReachable?.call(true);
        handler.next(response);
      },
      onError: (error, handler) async {
        onReachable?.call(error.response != null);
        if (error.response?.statusCode == 401) await _tokens.clear();
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _tokens;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) =>
      _send(() => _dio.post(path, data: data, options: _idempotency(idempotencyKey)));

  Future<dynamic> put(String path, {Object? data}) => _send(() => _dio.put(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Options? _idempotency(String? key) => key == null ? null : Options(headers: {'Idempotency-Key': key});

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
