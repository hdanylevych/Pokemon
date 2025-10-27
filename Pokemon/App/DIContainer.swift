//
//  DIContainer.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

class DIContainer {
    let imageLoader: ImageLoader
    let pokemonClient: PokemonClient
    let favoritesRepository: FavoritesRepository
    
    static func compose() -> DIContainer {
        return DIContainer(
            imageLoader: ImageLoader(),
            pokemonClient: PokemonClient(),
            favoritesRepository: FavoritesRepository()
        )
    }
    
    init(imageLoader: ImageLoader,
         pokemonClient: PokemonClient,
         favoritesRepository: FavoritesRepository) {
        self.imageLoader = imageLoader
        self.pokemonClient = pokemonClient
        self.favoritesRepository = favoritesRepository
    }
}
