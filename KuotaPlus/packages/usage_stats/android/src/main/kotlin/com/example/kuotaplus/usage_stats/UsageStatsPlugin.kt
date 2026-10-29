package com.example.kuotaplus.usage_stats

import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.time.ZoneId

/**
 * Pemakaian data seluler per aplikasi per hari (FR-7.2–7.4, docs/TECH-KuotaPlus.md bagian Android native).
 * Tidak butuh Activity, jadi juga berjalan di engine latar belakang WorkManager.
 */
class UsageStatsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "kuotaplus/usage_stats")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccessSettings" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "queryDailyMobileUsage" -> {
                if (!hasUsageAccess()) {
                    result.error("NO_USAGE_ACCESS", "Izin Usage Access belum diberikan.", null)
                    return
                }
                // Membaca beberapa hari NetworkStats bisa ratusan milidetik: jangan di main thread.
                val days = call.argument<Int>("days") ?: 7
                Thread {
                    val outcome = runCatching { queryDailyMobileUsage(days) }
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        outcome.fold(
                            { result.success(it) },
                            { result.error("QUERY_FAILED", it.message, null) },
                        )
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Satu entri per aplikasi per hari, sama dengan bucket body POST /usage/sync.
     * Batas hari mengikuti WIB (bukan zona HP) supaya sama dengan server. Hari ini ikut dikirim (kumulatif s.d. sekarang).
     */
    private fun queryDailyMobileUsage(days: Int): List<Map<String, Any>> {
        val manager = context.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val zone = ZoneId.of("Asia/Jakarta")
        val today = LocalDate.now(zone)
        val buckets = mutableListOf<Map<String, Any>>()

        for (offset in days - 1 downTo 0) {
            val date = today.minusDays(offset.toLong())
            val start = date.atStartOfDay(zone).toInstant().toEpochMilli()
            val end = date.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()

            val perUid = HashMap<Int, Long>()
            // subscriberId = null wajib di Android 10+. Hanya data seluler (OQ-12: Wi-Fi diabaikan).
            val stats = manager.querySummary(ConnectivityManager.TYPE_MOBILE, null, start, end)
            val bucket = NetworkStats.Bucket()
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                perUid[bucket.uid] = (perUid[bucket.uid] ?: 0L) + bucket.rxBytes + bucket.txBytes
            }
            stats.close()

            // Beberapa UID bisa jatuh ke grup yang sama (misalnya UID sistem), jadi dijumlahkan per package.
            val perPackage = LinkedHashMap<String, Pair<String, Long>>()
            for ((uid, bytes) in perUid) {
                if (bytes <= 0) continue
                val (packageName, label) = resolve(uid)
                val previous = perPackage[packageName]?.second ?: 0L
                perPackage[packageName] = label to previous + bytes
            }
            for ((packageName, value) in perPackage) {
                buckets.add(
                    mapOf(
                        "usage_date" to date.toString(),
                        "package_name" to packageName,
                        "label" to value.first,
                        "bytes_mobile" to value.second,
                    ),
                )
            }
        }
        return buckets
    }

    /** UID → (package_name, label). UID khusus dipetakan ke grup tetap (FR-7.4). */
    private fun resolve(uid: Int): Pair<String, String> {
        if (uid == NetworkStats.Bucket.UID_REMOVED) return "android.removed" to "Aplikasi terhapus"
        if (uid == NetworkStats.Bucket.UID_TETHERING) return "android.tethering" to "Hotspot"
        if (uid < Process.FIRST_APPLICATION_UID) return "android.system" to "Sistem Android"

        val pm = context.packageManager
        val packageName = pm.getPackagesForUid(uid)?.firstOrNull() ?: return "android.removed" to "Aplikasi terhapus"
        val label = try {
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
        return packageName to label
    }
}
