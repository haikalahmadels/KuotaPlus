import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token Sanctum. Android: Keystore, web: storage browser (FR-1.4).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;
  String? _token;
  bool _loaded = false;

  Future<String?> read() async {
    if (!_loaded) {
      _token = await _storage.read(key: _key);
      _loaded = true;
    }
    return _token;
  }

  Future<void> write(String token) async {
    await _storage.write(key: _key, value: token);
    _token = token;
    _loaded = true;
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    _token = null;
    _loaded = true;
  }
}
