//
//  SceneDelegate.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    var container: DIContainer? {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate?.container
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene),
              let container = container else { return }
        
        let window = UIWindow(windowScene: windowScene)
        
        let appCoordinator = AppCoordinator(container: container)
        appCoordinator.start()
        
        window.rootViewController = appCoordinator.navigationController
        window.makeKeyAndVisible()
        self.appCoordinator = appCoordinator
        self.window = window
    }
}

