//
//  BaseCoordinator.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

class BaseCoordinator: NSObject, Coordinator {
    let navigationController: UINavigationController
    let container: DIContainer
    
    var childCoordinators: [Coordinator] = []
    var onFinish: (() -> Void)?
    
    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }
    
    func start() {
        
    }
    
    func pop() {
        navigationController.popViewController(animated: true)
    }
}

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    var childCoordinators: [Coordinator] { get set }
    func start()
}

extension Coordinator {
    func store(_ child: Coordinator) { childCoordinators.append(child) }
    func free(_ child: Coordinator) {
        childCoordinators.removeAll { $0 === child }
    }
}
