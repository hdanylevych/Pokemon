//
//  HomeViewModel.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

enum ViewState: Equatable { case idle, loading, loaded, error(String) }

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var items: [PokemonModel] = []
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var favoritesCount = 0
    
    let pageSize = 20
    
    var cellUpdatesPublisher: AnyPublisher<Int, Never> { cellUpdates.eraseToAnyPublisher() }
    var navEventsPublisher: AnyPublisher<NavigationEvent, Never> { navEvents.eraseToAnyPublisher() }
    
    private let container: DIContainer
    
    private let cellUpdates = PassthroughSubject<Int, Never>()
    private let navEvents = PassthroughSubject<NavigationEvent, Never>()
    
    private var bag = Set<AnyCancellable>()
    private var pageOffset = 0

    init(container: DIContainer) {
        self.container = container
        
        container.favoritesRepository.$favorites
            .receive(on: DispatchQueue.main)
            .withPrevious(initial: Set<Int>())
            .sink { [weak self] prev, next in
                guard let self else { return }
                
                favoritesCount = next.count
                
                guard !items.isEmpty else { return }
                
                let changed = prev.symmetricDifference(next)
                changed.forEach { self.cellUpdates.send($0) }
            }
            .store(in: &bag)
    }
    
    func viewDidLoad() {
        loadPage(offset: 0, append: false)
    }
    
    func didScrollToBottom() {
        guard state != .loading else { return }
        pageOffset += pageSize
        loadPage(offset: pageOffset, append: true)
    }
    
    func item(for id: Int) -> PokemonModel? { items.first { $0.id == id } }
    
    func loadImageIfNeeded(forID id: Int) {
        guard let url = item(for: id)?.imageURL else { return }
        
        if container.imageLoader.cachedImage(for: url) != nil {
            cellUpdates.send(id)
            return
        }
        
        Future<UIImage?, Never> { [imageLoader = container.imageLoader] promise in
            Task { promise(.success(await imageLoader.image(for: url))) }
        }
        .receive(on: DispatchQueue.main)
        .sink { image in
            if image == nil { return }
            self.cellUpdates.send(id)
        }
        .store(in: &bag)
    }
    
    func retryTapped() {
        guard case .error = state else { return }
        
        state = .loading
        
        loadPage(offset: pageOffset, append: false)
    }
    
    func cardTapped(id: Int) {
        navEvents.send(.pokemonDetails(items.first(where: { $0.id == id })!))
    }
    
    func cachedImage(for url: URL) -> UIImage? { container.imageLoader.cachedImage(for: url) }
    
    func isFavorite(id: Int) -> Bool {
        container.favoritesRepository.isFavorite(id: id)
    }
    
    func toggleFavorite(id: Int) {
        container.favoritesRepository.toggle(id: id)
    }
    
    func delete(id: Int) {
        items = items.filter { $0.id != id }
        
        if isFavorite(id: id) {
            container.favoritesRepository.set(id: id, isOn: false)
        }
        
        if let url = item(for: id)?.imageURL {
            Task { await container.imageLoader.clearCache(for: url) }
        }
    }
    
    private func loadPage(offset: Int, append: Bool) {
        state = .loading
        container.pokemonClient.fetchPage(offset: offset, pageSize: pageSize)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure(let error) = completion {
                        self.state = .error(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] models in
                    guard let self else { return }
                    self.state = .loaded
                    self.items = append ? (self.items + models) : models
                    if !append { self.pageOffset = 0 }
                    models.forEach { self.cellUpdates.send($0.id) }
                }
            )
            .store(in: &bag)
    }
}
