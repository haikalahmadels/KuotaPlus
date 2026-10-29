import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diisi di main.dart dari token yang tersimpan, supaya router tahu status login sejak frame pertama.
final initialSignedInProvider = Provider<bool>((ref) => throw UnimplementedError('override di main.dart'));

/// True jika ada token. Berubah saat login, logout, atau server membalas 401.
final authProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

class AuthNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(initialSignedInProvider);

  void signedIn() => state = true;

  void signedOut() {
    state = false;
    // Cache data pengguna (beranda) tidak boleh terbaca oleh akun berikutnya di perangkat yang sama.
    SharedPreferences.getInstance().then((prefs) => prefs.clear());
  }
}
