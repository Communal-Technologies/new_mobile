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

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
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
