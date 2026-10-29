import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kuota_plus/core/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('byte di bawah 1 GB ditampilkan dalam MB bulat', () {
    expect(formatBytes(0), '0 MB');
    expect(formatBytes(950 * 1024 * 1024), '950 MB');
  });

  test('byte mulai 1 GB ditampilkan dalam GB dengan 1 desimal (1 GB = 1024 MB)', () {
    expect(formatBytes(1024 * 1024 * 1024), '1 GB');
    expect(formatBytes(1536 * 1024 * 1024), '1,5 GB');
    expect(formatBytes(15 * 1024 * 1024 * 1024), '15 GB');
  });

  test('rupiah tanpa desimal dengan pemisah titik', () {
    expect(formatRupiah(5000), 'Rp5.000');
    expect(formatRupiah(135000), 'Rp135.000');
  });

  test('waktu selalu ditampilkan dalam WIB', () {
    // 17:30 UTC = 00:30 WIB keesokan harinya.
    final time = DateTime.parse('2026-10-29T17:30:00Z');
    expect(formatDate(time), '30 Okt 2026');
    expect(formatDateTime(time), '30 Okt 2026, 00.30');
    expect(formatDateTime(DateTime.parse('2026-10-29T14:05:00+07:00')), '29 Okt 2026, 14.05');
  });

  test('nomor HP ditampilkan dalam format lokal berkelompok', () {
    expect(formatMsisdn('6288100000001'), '0881-0000-0001');
    expect(formatMsisdn('628123456789'), '0812-3456-789');
  });
}
