import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import LocalAuthentication
import WebKit
import CoreTelephony

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let deviceMetadataChannel = "fairytrail/device_metadata"
  private let appearanceChannel = "fairytrail/appearance"

  /// Last style requested from Flutter (`light` / `dark` / `system`).
  private static var storedInterfaceStyle = "system"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Show banners for local + remote notifications while the app is foregrounded.
  /// FlutterAppDelegate forwards this only to plugins; without presenting here,
  /// iOS suppresses the 20s explore reminder if the user stays in the app.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let metadata = FlutterMethodChannel(
      name: deviceMetadataChannel,
      binaryMessenger: messenger
    )
    metadata.setMethodCallHandler { [weak self] call, result in
      guard call.method == "collectExtras" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.collectExtras() ?? [:])
    }

    // Sync window UIUserInterfaceStyle with in-app theme so third-party
    // keyboards (e.g. Gboard) follow the app instead of the system theme.
    let appearance = FlutterMethodChannel(
      name: appearanceChannel,
      binaryMessenger: messenger
    )
    appearance.setMethodCallHandler { call, result in
      guard call.method == "setUserInterfaceStyle",
            let style = call.arguments as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      AppDelegate.storedInterfaceStyle = style
      AppDelegate.applyUserInterfaceStyle(style)
      result(nil)
    }
  }

  static func reapplyStoredUserInterfaceStyle() {
    applyUserInterfaceStyle(storedInterfaceStyle)
  }

  private static func applyUserInterfaceStyle(_ style: String) {
    let uiStyle: UIUserInterfaceStyle
    switch style {
    case "dark":
      uiStyle = .dark
    case "light":
      uiStyle = .light
    default:
      uiStyle = .unspecified
    }

    let run: () -> Void = {
      Self.applyUserInterfaceStyle(style, uiStyle: uiStyle, attempt: 1)
    }

    if Thread.isMainThread {
      run()
    } else {
      DispatchQueue.main.async(execute: run)
    }
  }

  private static func applyUserInterfaceStyle(
    _ style: String,
    uiStyle: UIUserInterfaceStyle,
    attempt: Int
  ) {
    var windows = Set<UIWindow>()
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows {
        windows.insert(window)
      }
      if let key = windowScene.keyWindow {
        windows.insert(key)
      }
    }

    for window in windows {
      window.overrideUserInterfaceStyle = uiStyle
      if let root = window.rootViewController {
        Self.apply(uiStyle, to: root)
      }
    }
    NSLog(
      "[Fairytrail] applied UIUserInterfaceStyle=%@ to %d window(s) (attempt %d)",
      style,
      windows.count,
      attempt
    )

    // Flutter window can appear after the first sync call.
    if windows.isEmpty && attempt < 5 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        Self.applyUserInterfaceStyle(style, uiStyle: uiStyle, attempt: attempt + 1)
      }
    }
  }

  private static func apply(_ style: UIUserInterfaceStyle, to controller: UIViewController) {
    controller.overrideUserInterfaceStyle = style
    for child in controller.children {
      apply(style, to: child)
    }
    if let presented = controller.presentedViewController {
      apply(style, to: presented)
    }
  }

  private func collectExtras() -> [String: Any?] {
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true

    let processInfo = ProcessInfo.processInfo
    let totalMemory = Int64(processInfo.physicalMemory)

    let attrs = try? FileManager.default.attributesOfFileSystem(
      forPath: NSHomeDirectory()
    )
    let totalDisk = (attrs?[.systemSize] as? NSNumber)?.int64Value
    let freeDisk = (attrs?[.systemFreeSize] as? NSNumber)?.int64Value

    let context = LAContext()
    var authError: NSError?
    let pinOrBiometric = context.canEvaluatePolicy(
      .deviceOwnerAuthentication,
      error: &authError
    )

    let userAgent = WKWebView().value(forKey: "userAgent") as? String

    // RN: simulator / unavailable → -1; otherwise 0..1
    let rawBattery = Double(device.batteryLevel)
    let batteryLevel: Double = rawBattery >= 0 ? rawBattery : -1

    // RN getCarrier() returns "--" when unavailable (incl. simulator).
    let carrier = Self.carrierName() ?? "--"

    let hasNotch: Bool = {
      guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })
      else { return false }
      return window.safeAreaInsets.top > 20
    }()

    let firstInstall: Int64? = {
      guard let url = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
      ).first,
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
        let date = attrs[.creationDate] as? Date
      else { return nil }
      return Int64(date.timeIntervalSince1970 * 1000)
    }()

    return [
      "carrier": carrier,
      "userAgent": userAgent,
      "ipAddress": Self.wifiAddress(),
      "macAddress": nil,
      "isAirplaneMode": nil,
      "adbEnabled": nil,
      "isDevelopmentSettingsMode": nil,
      "isOnExternalStorage": false,
      "canMockLocation": false,
      "hasNotch": hasNotch,
      "availableLocationProviders": [
        "gps": true,
        "network": true,
        "passive": true,
        "fused": true,
      ],
      "maxMemory": totalMemory,
      "totalMemory": totalMemory,
      "totalDiskCapacity": totalDisk,
      "freeDiskStorage": freeDisk,
      "firstInstallTime": firstInstall,
      "lastUpdateTime": firstInstall,
      "installReferrer": nil,
      "deviceType": device.userInterfaceIdiom == .pad ? "Tablet" : "Handset",
      "hookDetected": false,
      "isPinOrFingerprintSet": pinOrBiometric,
      "batteryLevel": batteryLevel,
      "powerState": [
        "lowPowerMode": processInfo.isLowPowerModeEnabled,
        "batteryLevel": batteryLevel,
        "batteryState": Self.batteryStateName(device.batteryState),
      ],
      "androidRootedDetectionMethods": nil,
    ]
  }

  private static func batteryStateName(_ state: UIDevice.BatteryState) -> String {
    switch state {
    case .charging: return "charging"
    case .full: return "full"
    case .unplugged: return "unplugged"
    default: return "unknown"
    }
  }

  private static func carrierName() -> String? {
    let info = CTTelephonyNetworkInfo()
    if let providers = info.serviceSubscriberCellularProviders {
      for carrier in providers.values {
        if let name = carrier.carrierName, !name.isEmpty, name != "--" {
          return name
        }
      }
    }
    return nil
  }

  private static func wifiAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let interface = ptr {
      defer { ptr = interface.pointee.ifa_next }
      let flags = Int32(interface.pointee.ifa_flags)
      guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) else { continue }
      guard (flags & IFF_LOOPBACK) == 0 else { continue }
      guard interface.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

      var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
      getnameinfo(
        interface.pointee.ifa_addr,
        addrLen,
        &hostname,
        socklen_t(hostname.count),
        nil,
        0,
        NI_NUMERICHOST
      )
      address = String(cString: hostname)
      break
    }
    return address
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
