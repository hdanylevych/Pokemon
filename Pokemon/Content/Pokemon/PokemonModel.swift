//
//  PokemonModel.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 24.10.2025.
//

struct PokemonModel: Decodable, Sendable, Hashable {
    let id: Int
    let name: String
    let weight: Int
    let height: Int
    let sprites: Sprites
    
    struct Sprites: Decodable, Sendable, Hashable {
        let other: Other
    }
    
    struct Other: Decodable, Sendable, Hashable {
        let official_artwork: OfficialArtwork
        
        private enum CodingKeys: String, CodingKey {
            case official_artwork = "official-artwork"
        }
    }
    
    struct OfficialArtwork: Decodable, Sendable, Hashable {
        let frontDefault: String
        
        enum CodingKeys: String, CodingKey {
            case frontDefault = "front_default"
        }
    }
    
    var imageURL: URL? {
        URL(string: sprites.other.official_artwork.frontDefault)
    }
}
