import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Keep screen on to prevent automatic locking/sleep
    UIApplication.shared.isIdleTimerDisabled = true
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeepLinkPlugin") {
      DeepLinkPlugin.register(with: registrar)
    }
  }
}

/// Forwards universal links to Dart over the same channels MainActivity uses
/// on Android: `app/deeplink` (initial link, device info) and
/// `app/deeplink/events` (links while running). The app uses the scene
/// lifecycle (FlutterSceneDelegate), so links arrive as scene callbacks.
/// Only hosts listed in the active entitlements are ever delivered.
final class DeepLinkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  FlutterSceneLifeCycleDelegate
{
  private var initialLink: String?
  private var pendingLink: String?
  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DeepLinkPlugin()
    let methods = FlutterMethodChannel(
      name: "app/deeplink", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "app/deeplink/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitialLink":
      result(initialLink)
      initialLink = nil
    case "getInstallReferrer":
      // iOS has no install referrer; the Dart side uses the server claim.
      result(nil)
    case "getDeviceInfo":
      result([
        "platform": "ios",
        "osVersion": UIDevice.current.systemVersion,
        "model": UIDevice.current.model,
        "timezone": TimeZone.current.identifier,
        "language": Locale.preferredLanguages.first ?? Locale.current.identifier,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    if let link = pendingLink {
      events(link)
      pendingLink = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: FlutterSceneLifeCycleDelegate

  /// Cold start: the link that launched the app.
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard
      let link = connectionOptions?.userActivities
        .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?
        .webpageURL?.absoluteString
    else { return false }
    initialLink = link
    return false
  }

  /// Warm start: a link opened while the app is running or backgrounded.
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let link = userActivity.webpageURL?.absoluteString
    else { return false }
    if let sink = eventSink {
      sink(link)
    } else {
      pendingLink = link
    }
    return true
  }
}
