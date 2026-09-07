import 'dart:convert';
import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fairytrail/config/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection_plus/flutter_jailbreak_detection_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Collects registration `deviceMetadata` with the same keys as the RN app
/// (`mobile/app/registration/index.tsx` + react-native-device-info / JailMonkey).
abstract final class DeviceMetadata {
  static const _nativeChannel = MethodChannel('fairytrail/device_metadata');

  static Future<Map<String, dynamic>> collect() async {
    final meta = <String, dynamic>{
      'deviceName': null,
      'isRealDevice': true,
      'systemName': Platform.isIOS
          ? 'iOS'
          : (Platform.isAndroid ? 'Android' : Platform.operatingSystem),
      'systemVersion': Platform.operatingSystemVersion,
      'brand': Platform.isIOS ? 'Apple' : null,
      'model': null,
      'deviceId': null,
      'deviceType': null,
      'appVersion': AppVersionInfo.version,
      'buildNumber': AppVersionInfo.build,
      'isTablet': null,
      'isPinOrFingerprintSet': null,
      'hasNotch': null,
      'firstInstallTime': null,
      'installReferrer': null,
      'lastUpdateTime': null,
      'carrier': null,
      'totalMemory': null,
      'maxMemory': null,
      'totalDiskCapacity': null,
      'freeDiskStorage': null,
      'batteryLevel': null,
      'isAirplaneMode': null,
      'isLocationEnabled': null,
      'availableLocationProviders': null,
      'powerState': null,
      'macAddress': null,
      'ipAddress': null,
      'userAgent': null,
      'supportedAbis': null,
      'isJailBroken': false,
      'canMockLocation': null,
      'trustFall': false,
      'isDebuggedMode': kDebugMode,
      'jailBrokenMessage': null,
      'hookDetected': null,
      'isOnExternalStorage': null,
      'adbEnabled': null,
      'isDevelopmentSettingsMode': null,
      'androidRootedDetectionMethods': null,
      'platform': Platform.operatingSystem,
      'source': 'flutter',
    };

    await _fillPackageInfo(meta);
    await _fillDeviceInfo(meta);
    await _fillBattery(meta);
    await _fillJailbreak(meta);
    await _fillLocationEnabled(meta);
    await _fillLocalAuth(meta);
    await _fillNetworkIp(meta);
    await _fillNativeExtras(meta);

    debugPrint(
      '[DeviceMetadata] collected '
      'isRealDevice=${meta['isRealDevice']} '
      'deviceName=${meta['deviceName']} '
      'batteryLevel=${meta['batteryLevel']} '
      'carrier=${meta['carrier']} '
      'totalMemory=${meta['totalMemory']} '
      'ipAddress=${meta['ipAddress']}',
    );

    return meta;
  }

  static Future<void> _fillPackageInfo(Map<String, dynamic> meta) async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) meta['appVersion'] = info.version;
      if (info.buildNumber.isNotEmpty) meta['buildNumber'] = info.buildNumber;
    } catch (e) {
      debugPrint('[DeviceMetadata] package_info failed: $e');
    }
  }

  static Future<void> _fillDeviceInfo(Map<String, dynamic> meta) async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        meta['deviceName'] = a.name.isNotEmpty ? a.name : a.model;
        meta['isRealDevice'] = a.isPhysicalDevice;
        meta['systemName'] = 'Android';
        meta['systemVersion'] = a.version.release;
        meta['brand'] = a.brand;
        meta['model'] = a.model;
        meta['deviceId'] = a.id;
        meta['deviceType'] = a.device;
        meta['isTablet'] = _androidLooksLikeTablet(a);
        meta['supportedAbis'] = jsonEncode(a.supportedAbis);
        // RN uses bytes; device_info_plus RAM is MB.
        meta['totalMemory'] = a.physicalRamSize * 1024 * 1024;
        meta['totalDiskCapacity'] = a.totalDiskSize;
        meta['freeDiskStorage'] = a.freeDiskSize;
        if (a.tags.contains('test-keys')) {
          meta['isDevelopmentSettingsMode'] = true;
        }
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        meta['deviceName'] = i.name;
        meta['isRealDevice'] = i.isPhysicalDevice;
        meta['systemName'] = i.systemName;
        meta['systemVersion'] = i.systemVersion;
        meta['brand'] = 'Apple';
        meta['model'] = i.utsname.machine;
        meta['deviceId'] = i.identifierForVendor;
        meta['deviceType'] = i.model;
        meta['isTablet'] = i.model.toLowerCase().contains('ipad');
        meta['totalMemory'] = i.physicalRamSize * 1024 * 1024;
        meta['totalDiskCapacity'] = i.totalDiskSize;
        meta['freeDiskStorage'] = i.freeDiskSize;
      }
    } catch (e) {
      debugPrint('[DeviceMetadata] device_info failed: $e');
    }
  }

  static Future<void> _fillBattery(Map<String, dynamic> meta) async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel; // 0–100
      // RN sends -1 when unavailable (iOS simulator).
      if (level < 0) {
        meta['batteryLevel'] = -1;
        meta['powerState'] = jsonEncode({
          'lowPowerMode': false,
          'batteryLevel': -1,
          'batteryState': 'unknown',
        });
        return;
      }
      final fraction = level / 100.0;
      meta['batteryLevel'] = fraction;
      final state = await battery.batteryState;
      meta['powerState'] = jsonEncode({
        'lowPowerMode': false,
        'batteryLevel': fraction,
        'batteryState': _batteryStateName(state),
      });
    } catch (e) {
      debugPrint('[DeviceMetadata] battery failed: $e');
      // Match RN device-info on iOS simulator when Battery API is unavailable.
      meta['batteryLevel'] = -1;
      meta['powerState'] = jsonEncode({
        'lowPowerMode': false,
        'batteryLevel': -1,
        'batteryState': 'unknown',
      });
    }
  }

  static String _batteryStateName(BatteryState state) {
    return switch (state) {
      BatteryState.charging => 'charging',
      BatteryState.full => 'full',
      BatteryState.connectedNotCharging => 'unplugged',
      BatteryState.discharging => 'unplugged',
      BatteryState.unknown => 'unknown',
    };
  }

  static Future<void> _fillJailbreak(Map<String, dynamic> meta) async {
    try {
      final jailbroken = await FlutterJailbreakDetectionPlus.jailbroken;
      meta['isJailBroken'] = jailbroken;
      meta['trustFall'] = jailbroken;
      if (Platform.isAndroid) {
        meta['isDebuggedMode'] =
            await FlutterJailbreakDetectionPlus.developerMode;
      }
    } catch (e) {
      debugPrint('[DeviceMetadata] jailbreak failed: $e');
    }
  }

  static Future<void> _fillLocationEnabled(Map<String, dynamic> meta) async {
    try {
      meta['isLocationEnabled'] = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[DeviceMetadata] location enabled failed: $e');
    }
  }

  static Future<void> _fillLocalAuth(Map<String, dynamic> meta) async {
    try {
      final auth = LocalAuthentication();
      final canBio = await auth.canCheckBiometrics;
      final canDevice = await auth.isDeviceSupported();
      meta['isPinOrFingerprintSet'] = canBio || canDevice;
    } catch (e) {
      debugPrint('[DeviceMetadata] local_auth failed: $e');
    }
  }

  static Future<void> _fillNetworkIp(Map<String, dynamic> meta) async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        meta['ipAddress'] = wifiIp;
      }
    } catch (e) {
      debugPrint('[DeviceMetadata] network_info failed: $e');
    }
  }

  static Future<void> _fillNativeExtras(Map<String, dynamic> meta) async {
    try {
      final extras = await _nativeChannel.invokeMapMethod<String, dynamic>(
        'collectExtras',
      );
      if (extras != null) {
        void put(String key, dynamic value) {
          if (value == null) return;
          meta[key] = value;
        }

        put('carrier', extras['carrier']);
        put('userAgent', extras['userAgent']);
        put('ipAddress', extras['ipAddress'] ?? meta['ipAddress']);
        put('macAddress', extras['macAddress']);
        put('isAirplaneMode', extras['isAirplaneMode']);
        put('adbEnabled', extras['adbEnabled']);
        put('isDevelopmentSettingsMode', extras['isDevelopmentSettingsMode']);
        put('isOnExternalStorage', extras['isOnExternalStorage']);
        put('canMockLocation', extras['canMockLocation']);
        put('hasNotch', extras['hasNotch']);
        put('maxMemory', extras['maxMemory']);
        put('totalMemory', extras['totalMemory'] ?? meta['totalMemory']);
        put(
          'totalDiskCapacity',
          extras['totalDiskCapacity'] ?? meta['totalDiskCapacity'],
        );
        put(
          'freeDiskStorage',
          extras['freeDiskStorage'] ?? meta['freeDiskStorage'],
        );
        put('firstInstallTime', extras['firstInstallTime']);
        put('lastUpdateTime', extras['lastUpdateTime']);
        put('installReferrer', extras['installReferrer']);
        put('deviceType', extras['deviceType'] ?? meta['deviceType']);
        put('hookDetected', extras['hookDetected']);
        put(
          'isPinOrFingerprintSet',
          extras['isPinOrFingerprintSet'] ?? meta['isPinOrFingerprintSet'],
        );

        final providers = extras['availableLocationProviders'];
        if (providers != null) {
          meta['availableLocationProviders'] =
              providers is String ? providers : jsonEncode(providers);
        }

        final rooted = extras['androidRootedDetectionMethods'];
        if (rooted != null) {
          meta['androidRootedDetectionMethods'] =
              rooted is String ? rooted : jsonEncode(rooted);
        }

        // Include native battery even when -1 (iOS simulator / unavailable).
        if (extras['batteryLevel'] != null) {
          meta['batteryLevel'] = extras['batteryLevel'];
        }
        if (extras['powerState'] != null) {
          final ps = extras['powerState'];
          meta['powerState'] = ps is String ? ps : jsonEncode(ps);
        }
      }
    } catch (e) {
      debugPrint('[DeviceMetadata] native extras failed: $e');
    }

    // RN getCarrier() → "--" when unknown; getBatteryLevel() → -1 when N/A.
    final carrier = meta['carrier'];
    if (carrier == null || (carrier is String && carrier.trim().isEmpty)) {
      meta['carrier'] = '--';
    }
    meta['batteryLevel'] ??= -1;
  }

  static bool _androidLooksLikeTablet(AndroidDeviceInfo a) {
    final model = a.model.toLowerCase();
    return model.contains('tablet') || model.contains('tab');
  }
}
