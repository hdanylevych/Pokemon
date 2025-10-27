//
//  PokemonClient.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 25.10.2025.
//

private struct PokemonListResponse: Decodable {
    struct Item: Decodable {
        let name: String
        let url: URL
    }
    
    let count: Int
    let next: URL?
    let previous: URL?
    let results: [Item]
}

enum PokemonAPIError: Error {
    case badStatus(Int)
    case invalidURL
}

final class PokemonClient {
    private let baseURL = URL(string: "https://pokeapi.co/api/v2")!
    private let session: URLSession
    private let decoder = JSONDecoder()
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchPage(offset: Int, pageSize: Int,
                   maxConcurrentDetailLoads: Int = 6) -> AnyPublisher<[PokemonModel], Error> {
        
        var comps = URLComponents(url: baseURL.appendingPathComponent("pokemon"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit",  value: String(pageSize))
        ]
        
        guard let pageURL = comps?.url else {
            return Fail(error: PokemonAPIError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: pageURL)
            .tryMap { data, response in
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                    throw PokemonAPIError.badStatus(code)
                }
                return data
            }
            .decode(type: PokemonListResponse.self, decoder: decoder)
            .flatMap { [session, decoder] page -> AnyPublisher<[PokemonModel], Error> in
                let indexed = page.results.enumerated().map { ($0.offset, $0.element) }

                return Publishers.Sequence(sequence: indexed)
                    .flatMap(maxPublishers: .max(maxConcurrentDetailLoads)) { (idx, item) in
                        session.dataTaskPublisher(for: item.url)
                            .tryMap { data, response in
                                guard let http = response as? HTTPURLResponse,
                                      (200..<300).contains(http.statusCode) else {
                                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                                    throw PokemonAPIError.badStatus(code)
                                }
                                return data
                            }
                            .decode(type: PokemonModel.self, decoder: decoder)
                            .map { (idx, $0) }
                            .eraseToAnyPublisher()
                    }
                    .collect()
                    .tryMap { pairs -> [PokemonModel] in
                        var ordered = Array<PokemonModel?>(repeating: nil, count: page.results.count)
                        for (idx, model) in pairs { ordered[idx] = model }
                        return ordered.compactMap { $0 }
                    }
                    .eraseToAnyPublisher()
            }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .eraseToAnyPublisher()
    }
}
