import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuota_plus/core/api_exception.dart';

DioException _error({int? status, Object? body}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    response: status == null ? null : Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  test('error API membawa code, message, meta, dan errors', () {
    final e = ApiException.fromDio(_error(status: 422, body: {
      'message': 'Pulsa tidak cukup.',
      'code': 'INSUFFICIENT_BALANCE',
      'meta': {'shortfall': 7000},
      'errors': {
        'payment_method': ['Pulsa tidak cukup.'],
      },
    }));

    expect(e.code, 'INSUFFICIENT_BALANCE');
    expect(e.status, 422);
    expect(e.meta['shortfall'], 7000);
    expect(e.errors['payment_method'], ['Pulsa tidak cukup.']);
    expect(e.isNetwork, isFalse);
  });

  test('tanpa respons dianggap error jaringan', () {
    expect(ApiException.fromDio(_error()).isNetwork, isTrue);
  });

  test('respons tanpa format API (misalnya halaman HTML) tetap jadi ApiException', () {
    final e = ApiException.fromDio(_error(status: 502, body: '<html>'));
    expect(e.code, 'HTTP_502');
    expect(e.isNetwork, isFalse);
  });
}
