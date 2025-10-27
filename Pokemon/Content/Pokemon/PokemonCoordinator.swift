//
//  PokemonCoordinator.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

class PokemonCoordinator: BaseCoordinator {
    private let viewModel: PokemonViewModel
    private let view: PokemonViewController
    
    private var bag = Set<AnyCancellable>()
    
    init(navigationController: UINavigationController, container: DIContainer, model: PokemonModel) {
        viewModel = PokemonViewModel(container: container, model: model)
        view = PokemonViewController(viewModel: viewModel)
        
        super.init(navigationController: navigationController, container: container)
    }
    
    override func start() {
        viewModel.navEventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .pop:
                    self?.pop()
                default:
                    break
                }
            }
            .store(in: &bag)
        
        navigationController.pushViewController(view, animated: true)
        navigationController.delegate = self
    }
}

extension PokemonCoordinator: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let stillVisible = navigationController.viewControllers.contains { $0 is PokemonViewController }
        if !stillVisible { onFinish?() }
    }
}
