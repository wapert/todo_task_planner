import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications: the plugin implements the
    // UNUserNotificationCenterDelegate callbacks but never installs itself as
    // the delegate — it relies on FlutterAppDelegate being the delegate and
    // forwarding to registered plugins. Without this, a reminder that fires
    // while the app is in the foreground is silently dropped.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // The badge mirrors the number of overdue reminders still showing a '!' in
  // the task list. It is NOT cleared on launch: a reminder the user has not
  // dismissed yet is still outstanding, and zeroing it here would lose that.
  private func registerBadgeChannel(_ registrar: FlutterPluginRegistry) {
    guard let messenger = registrar.registrar(forPlugin: "TodoPlannerBadge")?.messenger()
    else { return }
    let channel = FlutterMethodChannel(
      name: "todo_planner/badge",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setBadge", let count = call.arguments as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(count)
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
      }
      result(nil)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBadgeChannel(engineBridge.pluginRegistry)
  }
}
