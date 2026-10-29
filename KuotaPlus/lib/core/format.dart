import 'package:intl/intl.dart';

// Butuh initializeDateFormatting('id_ID') sebelum dipakai (lihat main.dart).

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;

final _gbFormat = NumberFormat('#,##0.#', 'id_ID');
final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

/// Byte → "750 MB" atau "1,5 GB" (1 GB = 1024 MB).
String formatBytes(int bytes) =>
    bytes < _gb ? '${(bytes / _mb).round()} MB' : '${_gbFormat.format(bytes / _gb)} GB';

/// 5000 → "Rp5.000".
String formatRupiah(int amount) => _rupiah.format(amount);

/// "6288100000001" → "0881-0000-0001".
String formatMsisdn(String msisdn) {
  final local = msisdn.startsWith('62') ? '0${msisdn.substring(2)}' : msisdn;
  return [
    for (var i = 0; i < local.length; i += 4) local.substring(i, i + 4 > local.length ? local.length : i + 4),
  ].join('-');
}

/// Waktu dari API selalu ditampilkan dalam WIB, apa pun zona waktu perangkat.
DateTime toWib(DateTime time) => time.toUtc().add(const Duration(hours: 7));

/// Tanggal tanpa jam dari API ("2026-11-23", hari WIB) → 00:00 WIB hari itu,
/// supaya [formatDate] menampilkan hari yang sama di zona waktu perangkat mana pun.
DateTime parseDate(String date) => DateTime.parse('${date}T00:00:00+07:00');

/// "29 Okt 2026".
String formatDate(DateTime time) => DateFormat('d MMM yyyy', 'id_ID').format(toWib(time));

/// "29 Okt 2026, 14.05".
String formatDateTime(DateTime time) => DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(toWib(time));
