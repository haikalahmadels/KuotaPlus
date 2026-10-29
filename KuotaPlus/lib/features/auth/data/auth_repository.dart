import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/platform.dart';
import '../../../core/token_storage.dart';

/// Respons `POST /auth/otp/request`.
class OtpChallenge {
  const OtpChallenge({
    required this.msisdn,
    required this.expiresAt,
    required this.resendAvailableAt,
    this.demoOtp,
  });

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        msisdn: json['msisdn'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        resendAvailableAt: DateTime.parse(json['resend_available_at'] as String),
        demoOtp: json['demo_otp'] as String?,
      );

  final String msisdn;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  /// Hanya ada di Mode Demo (APP_ENV=local), FR-1.3.
  final String? demoOtp;
}

class AuthRepository {
  AuthRepository(this._api, this._tokens, {required this.onSignedIn, required this.onSignedOut});

  final ApiClient _api;
  final TokenStorage _tokens;
  final void Function() onSignedIn;
  final void Function() onSignedOut;

  Future<OtpChallenge> requestOtp(String msisdn) async {
    final body = await _api.post('/auth/otp/request', data: {'msisdn': msisdn});
    return OtpChallenge.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> verify(String msisdn, String code) async {
    final body = await _api.post('/auth/otp/verify', data: {
      'msisdn': msisdn,
      'code': code,
      'device_name': isAndroidApp ? 'android' : 'web',
    });
    await _tokens.write(body['data']['token'] as String);
    onSignedIn();
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Tetap keluar di perangkat walau server tidak terjangkau; token di server tidak bisa dicabut saat offline.
    } finally {
      await _tokens.clear();
      onSignedOut();
    }
  }
}
