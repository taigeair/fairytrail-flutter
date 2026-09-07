package app.fairytrail.release

import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.telephony.TelephonyManager
import android.webkit.WebSettings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections

/**
 * Mirrors react-native-device-info + jail-monkey fields used at registration.
 * Extends [FlutterFragmentActivity] for Stripe PaymentSheet.
 */
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "fairytrail/device_metadata"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "collectExtras") {
                    try {
                        result.success(collectExtras())
                    } catch (e: Exception) {
                        result.error("device_metadata", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun collectExtras(): Map<String, Any?> {
        val pm = packageManager
        val pkg = packageName
        val pInfo = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(pkg, 0)
            }
        } catch (_: Exception) {
            null
        }

        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager

        val carrier = try {
            telephony?.networkOperatorName?.takeIf { it.isNotBlank() }
                ?: telephony?.simOperatorName?.takeIf { it.isNotBlank() }
                ?: "--"
        } catch (_: Exception) {
            "--"
        }

        val userAgent = try {
            WebSettings.getDefaultUserAgent(this)
        } catch (_: Exception) {
            System.getProperty("http.agent")
        }

        val isAirplaneMode = try {
            Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
        } catch (_: Exception) {
            null
        }

        val adbEnabled = try {
            Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        } catch (_: Exception) {
            null
        }

        val isDevelopmentSettingsMode = try {
            Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        } catch (_: Exception) {
            null
        }

        val providers = mutableMapOf<String, Boolean>()
        try {
            providers["gps"] = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true
            providers["network"] =
                locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
            providers["passive"] =
                locationManager?.isProviderEnabled(LocationManager.PASSIVE_PROVIDER) == true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                providers["fused"] =
                    locationManager?.isProviderEnabled(LocationManager.FUSED_PROVIDER) == true
            } else {
                providers["fused"] = true
            }
        } catch (_: Exception) {
        }

        val ipAddress = try {
            Collections.list(NetworkInterface.getNetworkInterfaces())
                .flatMap { Collections.list(it.inetAddresses) }
                .firstOrNull { !it.isLoopbackAddress && it.hostAddress?.contains(':') != true }
                ?.hostAddress
        } catch (_: Exception) {
            null
        }

        val macAddress = try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            @Suppress("DEPRECATION")
            wifi?.connectionInfo?.macAddress?.takeIf { it != "02:00:00:00:00:00" }
        } catch (_: Exception) {
            null
        }

        val isOnExternalStorage = try {
            val filesDir = applicationContext.filesDir.absolutePath
            Environment.isExternalStorageEmulated() &&
                filesDir.startsWith(Environment.getExternalStorageDirectory().absolutePath)
        } catch (_: Exception) {
            false
        }

        val canMockLocation = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                false
            } else {
                @Suppress("DEPRECATION")
                Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                ) != "0"
            }
        } catch (_: Exception) {
            false
        }

        val hasNotch = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.decorView.rootWindowInsets?.displayCutout != null
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }

        val maxMemory = Runtime.getRuntime().maxMemory()
        val totalMemory = try {
            val mi = android.app.ActivityManager.MemoryInfo()
            (getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager)
                .getMemoryInfo(mi)
            mi.totalMem
        } catch (_: Exception) {
            null
        }

        // Battery via BatteryManager — more reliable than waiting on Flutter battery_plus.
        val batteryLevel = try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
            val pct = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
            if (pct in 0..100) pct / 100.0 else -1.0
        } catch (_: Exception) {
            -1.0
        }

        val powerState = mapOf(
            "lowPowerMode" to false,
            "batteryLevel" to batteryLevel,
            "batteryState" to "unplugged",
        )

        val deviceType = try {
            val isTablet = resources.configuration.smallestScreenWidthDp >= 600
            if (isTablet) "Tablet" else "Handset"
        } catch (_: Exception) {
            "Handset"
        }

        return mapOf(
            "carrier" to carrier,
            "userAgent" to userAgent,
            "ipAddress" to ipAddress,
            "macAddress" to macAddress,
            "isAirplaneMode" to isAirplaneMode,
            "adbEnabled" to adbEnabled,
            "isDevelopmentSettingsMode" to isDevelopmentSettingsMode,
            "isOnExternalStorage" to isOnExternalStorage,
            "canMockLocation" to canMockLocation,
            "hasNotch" to hasNotch,
            "availableLocationProviders" to providers,
            "maxMemory" to maxMemory,
            "totalMemory" to totalMemory,
            "firstInstallTime" to pInfo?.firstInstallTime,
            "lastUpdateTime" to pInfo?.lastUpdateTime,
            "installReferrer" to null,
            "deviceType" to deviceType,
            "hookDetected" to false,
            "isPinOrFingerprintSet" to null,
            "batteryLevel" to batteryLevel,
            "powerState" to powerState,
            "androidRootedDetectionMethods" to mapOf(
                "rootBeer" to mapOf(
                    "detectPotentiallyDangerousApps" to false,
                    "checkForDangerousProps" to false,
                    "checkForRootNative" to false,
                    "checkForSuBinary" to false,
                    "checkForRWPaths" to false,
                    "checkForMagiskBinary" to false,
                    "detectRootManagementApps" to false,
                    "detectTestKeys" to (Build.TAGS?.contains("test-keys") == true),
                    "checkSuExists" to false,
                ),
                "jailMonkey" to false,
            ),
        )
    }
}
