import 'package:dio/dio.dart';

/// Error dari API dengan `code` stabil (docs/API-KuotaPlus.md, Lampiran A).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.status,
    this.meta = const {},
    this.errors = const {},
  });

  /// Tidak ada respons dari server: Laragon mati, IP salah, atau offline.
  static const network = 'NETWORK';

  final String code;
  final String message;
  final int? status;
  final Map<String, dynamic> meta;
  final Map<String, List<String>> errors;

  bool get isNetwork => code == network;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(code: network, message: 'Tidak bisa terhubung ke server.');
    }

    final body = response.data;
    if (body is Map && body['code'] is String) {
      return ApiException(
        code: body['code'] as String,
        message: body['message'] as String? ?? 'Terjadi kesalahan.',
        status: response.statusCode,
        meta: (body['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
        errors: (body['errors'] as Map?)?.map(
              (field, messages) => MapEntry(field as String, (messages as List).cast<String>()),
            ) ??
            const {},
      );
    }

    return ApiException(
      code: 'HTTP_${response.statusCode}',
      message: 'Terjadi kesalahan di server.',
      status: response.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $message)';
}
