import 'package:flutter_test/flutter_test.dart';
import 'package:kuota_plus/app/router.dart';

void main() {
  String? redirect(bool signedIn, String location) => authRedirect(signedIn: signedIn, uri: Uri.parse(location));

  test('belum login diarahkan ke login dengan route asal', () {
    expect(redirect(false, '/home'), '/login?from=%2Fhome');
    expect(redirect(false, '/history/12?tab=share'), '/login?from=%2Fhistory%2F12%3Ftab%3Dshare');
    expect(redirect(false, '/login'), isNull);
    expect(redirect(false, '/login/otp'), isNull);
  });

  test('setelah login kembali ke route asal, atau beranda', () {
    expect(redirect(true, '/login/otp?from=%2Fhistory%2F12'), '/history/12');
    expect(redirect(true, '/login'), '/home');
    expect(redirect(true, '/home'), isNull);
  });

  test('parameter from hanya menerima route internal', () {
    expect(redirect(true, '/login?from=https%3A%2F%2Fevil.example'), '/home');
    expect(redirect(true, '/login?from=%2F%2Fevil.example'), '/home');
  });
}
