//
//  Publisher.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 26.10.2025.
//

extension Publisher {
    func withPrevious(initial: Output) -> AnyPublisher<(Output, Output), Failure> {
        scan((initial, initial)) { ($0.1, $1) }.eraseToAnyPublisher()
    }
}
