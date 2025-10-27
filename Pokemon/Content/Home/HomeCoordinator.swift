//
//  HomeCoordinator.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

final class HomeCoordinator: BaseCoordinator {
    private let viewModel: HomeViewModel
    private let view: HomeViewController
    
    private var bag = Set<AnyCancellable>()
    
    override init(navigationController: UINavigationController, container: DIContainer) {
        viewModel = HomeViewModel(container: container)
        view = HomeViewController(viewModel: viewModel)
        
        super.init(navigationController: navigationController, container: container)
    }
    
    override func start() {
        viewModel.navEventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .pokemonDetails(let model):
                    self?.startPokemon(model: model)
                case .pop:
                    self?.pop()
                }
            }
            .store(in: &bag)

        navigationController.setViewControllers([view], animated: false)
        navigationController.delegate = self
    }
    
    private func startPokemon(model: PokemonModel) {
        let pokemon = PokemonCoordinator(navigationController: navigationController, container: container, model: model)
        store(pokemon)
        pokemon.onFinish = { [weak self, weak pokemon] in
            guard let self, let pokemon else { return }
            self.free(pokemon)
        }
        pokemon.start()
    }
}

extension HomeCoordinator: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let stillVisible = navigationController.viewControllers.contains { $0 is HomeViewController }
        if !stillVisible { onFinish?() }
    }
}
