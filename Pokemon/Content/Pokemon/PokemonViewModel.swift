//
//  PokemonViewModel.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

final class PokemonViewModel: ObservableObject {
    @Published private(set) var isFavorite = false
    @Published private(set) var image: UIImage? = nil
    @Published private(set) var isImageLoading = false
    
    var navEventsPublisher: AnyPublisher<NavigationEvent, Never> { navEvents.eraseToAnyPublisher() }
    
    private let container: DIContainer
    let model: PokemonModel
    
    private let navEvents = PassthroughSubject<NavigationEvent, Never>()
    
    init(container: DIContainer, model: PokemonModel) {
        self.container = container
        self.model = model
        self.isFavorite = container.favoritesRepository.isFavorite(id: model.id)
    }
    
    func toggleFavorite() {
        container.favoritesRepository.toggle(id: model.id)
        isFavorite = container.favoritesRepository.isFavorite(id: model.id)
    }
    
    func loadImageIfNeeded() {
        guard image == nil, let url = model.imageURL else { return }
        
        isImageLoading = true
        
        Task {
            let img = await container.imageLoader.image(for: url)
            await MainActor.run {
                self.image = img
                self.isImageLoading = false
            }
        }
    }
}
