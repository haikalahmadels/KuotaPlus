import 'package:flutter/foundation.dart';

/// Fitur khusus Android (sync pemakaian, notifikasi lokal) hanya aktif jika ini true.
bool get isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
