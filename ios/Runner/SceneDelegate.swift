import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Window may appear after Flutter theme sync — re-apply so Gboard follows
    // the app theme instead of system Appearance.
    DispatchQueue.main.async {
      AppDelegate.reapplyStoredUserInterfaceStyle()
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    AppDelegate.reapplyStoredUserInterfaceStyle()
  }
}
