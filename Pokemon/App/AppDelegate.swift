//
//  AppDelegate.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    let container = DIContainer.compose()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        PersistenceController.shared.configure()
        container.favoritesRepository.configure()
        
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
