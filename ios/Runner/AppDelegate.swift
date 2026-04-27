import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Snapshot-blocking overlay shown during app-switcher backgrounding.
  ///
  /// iOS captures the app's frame for the App Switcher *before*
  /// `applicationDidEnterBackground` is called. Any Flutter-side blur runs
  /// too late to protect that snapshot. The standard pattern: install a
  /// solid view on the key window in `applicationWillResignActive` so the
  /// captured snapshot is the overlay, then remove it on resume.
  private var snapshotOverlay: UIView?

  /// Audit M38: holds the strong reference to the biometric key channel
  /// for the lifetime of the app; without this the channel deallocates
  /// after `application(_:didFinishLaunching...)` returns and platform
  /// invocations never reach Swift.
  private var biometricKeyChannel: BiometricKeyChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Audit M38: register the biometric key channel so Dart can generate
    // / sign / revoke ECDSA P-256 keys via the Secure Enclave.
    if let controller = self.window?.rootViewController as? FlutterViewController {
      self.biometricKeyChannel = BiometricKeyChannel(
        messenger: controller.binaryMessenger
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    showSnapshotOverlay()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hideSnapshotOverlay()
  }

  private func showSnapshotOverlay() {
    guard snapshotOverlay == nil,
          let window = UIApplication.shared.windows.first else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
    overlay.tag = 1_999
    // Centered Communal logo would go here if we ever add Image assets to
    // the iOS bundle; the solid color is enough to protect PII from the App
    // Switcher snapshot today.
    window.addSubview(overlay)
    snapshotOverlay = overlay
  }

  private func hideSnapshotOverlay() {
    snapshotOverlay?.removeFromSuperview()
    snapshotOverlay = nil
  }
}
