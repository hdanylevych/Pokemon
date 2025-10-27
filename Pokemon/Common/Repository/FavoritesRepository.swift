//
//  FavoritesRepository.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 25.10.2025.
//

final class FavoritesRepository: ObservableObject {
    @Published var favorites = Set<Int>()
    
    init() {
    }
    
    func configure() {
        refreshCache()
    }
    
    func isFavorite(id: Int) -> Bool { favorites.contains(id) }
    
    func toggle(id: Int) {
        let isOn = isFavorite(id: id)
        set(id: id, isOn: !isOn)
    }
    
    func set(id: Int, isOn: Bool) {
        if isOn {
            let entity = CDFavorite.get(CDFavorite.self, by: id)
            if entity == nil {
                CDFavorite.create(with: id)
            }
        } else {
            CDFavorite.delete(CDFavorite.self, id: id)
        }
        
        self.refreshCache()
    }
    
    private func refreshCache() {
        let rows = CDFavorite.getAll(CDFavorite.self)
        let set = Set(rows.compactMap { $0.id }.map(Int.init))
        self.favorites = set
    }
}
