//
//  AppCoordinator.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

final class AppCoordinator: Coordinator {
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    
    private let container: DIContainer
    
    init(navigationController: UINavigationController = UINavigationController(),
         container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }
    
    func start() {
        startHome()
    }
    
    private func startHome() {
        let coordinator = HomeCoordinator(navigationController: navigationController, container: container)
        store(coordinator)
        coordinator.start()
    }
}
