import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  private var privacyOverlay: UIView?
  private var captureObserver: NSObjectProtocol?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.updatePrivacyOverlay()
    }
    updatePrivacyOverlay()
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    // Blur the window before iOS captures the task-switcher snapshot.
    showPrivacyOverlay()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    updatePrivacyOverlay()
  }

  deinit {
    if let captureObserver {
      NotificationCenter.default.removeObserver(captureObserver)
    }
  }

  private func updatePrivacyOverlay() {
    if UIScreen.main.isCaptured {
      showPrivacyOverlay()
    } else {
      hidePrivacyOverlay()
    }
  }

  private func showPrivacyOverlay() {
    guard let window, privacyOverlay == nil else { return }
    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.accessibilityElementsHidden = true
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }

}
