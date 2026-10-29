# usage_stats

Plugin Flutter lokal untuk Kuota+ (Android saja). Dibuat sebagai plugin, bukan `MethodChannel` di `MainActivity`,
supaya juga terdaftar di Flutter engine latar belakang milik WorkManager (lihat `docs/TECH-KuotaPlus.md`).

Method channel `kuotaplus/usage_stats`: `hasUsageAccess`, `openUsageAccessSettings`, `queryDailyMobileUsage`.
