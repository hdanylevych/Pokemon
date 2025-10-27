//
//  PokemonClientTests.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 26.10.2025.
//

import XCTest
@testable import Pokemon

final class PokemonClientTests: XCTestCase {
    var session: URLSession!
    var client: PokemonClient!
    var bag: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [TestURLProtocol.self]
        session = URLSession(configuration: cfg)
        client = PokemonClient(session: session)
        bag = []
        TestURLProtocol.specs = [:]
        TestURLProtocol.onStart = nil
        TestURLProtocol.onFinish = nil
    }
    
    override func tearDown() {
        bag = nil
        client = nil
        session.invalidateAndCancel()
        session = nil
        super.tearDown()
    }
    
    private func makePageURL(offset: Int, limit: Int) -> URL {
        var c = URLComponents(string: "https://pokeapi.co/api/v2/pokemon")!
        c.queryItems = [
            .init(name: "offset", value: String(offset)),
            .init(name: "limit", value: String(limit)),
        ]
        return c.url!
    }
    
    private func pageJSON(ids: [Int]) -> Data {
        let results: [[String: Any]] = ids.map { id in
            [
                "name": "poke-\(id)",
                "url": "https://pokeapi.co/api/v2/pokemon/\(id)/"
            ]
        }
        let obj: [String: Any] = [
            "count": 10000,
            "next": NSNull(),
            "previous": NSNull(),
            "results": results
        ]
        return try! JSONSerialization.data(withJSONObject: obj, options: [])
    }
    
    // Craft a PokeAPI-like detail JSON; adjust if your PokemonModel needs more/less
    private func detailJSON(id: Int, name: String) -> Data {
        let obj: [String: Any] = [
            "id": id,
            "name": name,
            "weight": 61,
            "height": 143,
            "sprites": [
                "other": [
                    "official-artwork": [
                        "front_default": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png"
                    ]
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: obj, options: [])
    }
    
    private func expect(_ description: String) -> XCTestExpectation {
        expectation(description: description)
    }
    
    func test_fetchPage_success_ordersByIndex() {
        // Given a page with 3 results
        let ids = [21, 7, 150]
        let pageURL = makePageURL(offset: 0, limit: 3)
        TestURLProtocol.specs[pageURL] = .init(status: 200, data: pageJSON(ids: ids), delay: 0)
        
        // And detail endpoints for each
        for id in ids {
            let detail = URL(string: "https://pokeapi.co/api/v2/pokemon/\(id)/")!
            TestURLProtocol.specs[detail] = .init(status: 200, data: detailJSON(id: id, name: "poke-\(id)"), delay: 0.02) // small delay to shuffle arrival
        }
        
        let done = expect("fetch page")
        var received: [PokemonModel]?
        
        client.fetchPage(offset: 0, pageSize: 3)
            .sink(receiveCompletion: { completion in
                if case .failure(let e) = completion { XCTFail("Unexpected error: \(e)") }
                done.fulfill()
            }, receiveValue: { models in
                received = models
            })
            .store(in: &bag)
        
        wait(for: [done], timeout: 2)
        
        // Then: correct count and order matches the page order [21, 7, 150]
        XCTAssertEqual(received?.count, 3)
        // If your PokemonModel has id property:
        let recIds = received?.map { $0.id } ?? []
        XCTAssertEqual(recIds, ids, "Detail results must be ordered by page index")
    }
    
    func test_fetchPage_pageHTTPError_propagates() {
        let badURL = makePageURL(offset: 40, limit: 20)
        TestURLProtocol.specs[badURL] = .init(status: 503, data: Data(), delay: 0)
        
        let done = expect("error")
        var gotError = false
        
        client.fetchPage(offset: 40, pageSize: 20)
            .sink(receiveCompletion: { completion in
                defer { done.fulfill() }
                if case .failure = completion { gotError = true }
            }, receiveValue: { _ in
                XCTFail("Should not emit value on page HTTP error")
            })
            .store(in: &bag)
        
        wait(for: [done], timeout: 1)
        XCTAssertTrue(gotError)
    }
    
    func test_fetchPage_detailHTTPError_propagates() {
        // Page with two items
        let ids = [1, 2]
        let pageURL = makePageURL(offset: 0, limit: 2)
        TestURLProtocol.specs[pageURL] = .init(status: 200, data: pageJSON(ids: ids), delay: 0)
        
        // First detail OK, second 404
        let ok = URL(string: "https://pokeapi.co/api/v2/pokemon/1/")!
        let bad = URL(string: "https://pokeapi.co/api/v2/pokemon/2/")!
        TestURLProtocol.specs[ok] = .init(status: 200, data: detailJSON(id: 1, name: "poke-1"), delay: 0)
        TestURLProtocol.specs[bad] = .init(status: 404, data: Data(), delay: 0)
        
        let done = expect("detail error")
        var gotError = false
        
        client.fetchPage(offset: 0, pageSize: 2)
            .sink(receiveCompletion: { completion in
                defer { done.fulfill() }
                if case .failure = completion { gotError = true }
            }, receiveValue: { _ in
                XCTFail("Should fail when one of the detail requests fails")
            })
            .store(in: &bag)
        
        wait(for: [done], timeout: 2)
        XCTAssertTrue(gotError)
    }
    
    func test_fetchPage_respects_maxConcurrentDetailLoads() {
        // Page with 12 results; cap concurrency at 3
        let ids = Array(1...12)
        let pageURL = makePageURL(offset: 0, limit: ids.count)
        TestURLProtocol.specs[pageURL] = .init(status: 200, data: pageJSON(ids: ids), delay: 0)
        
        // Track peak concurrency via onStart/onFinish hooks
        let lock = NSLock()
        var active = 0
        var peak = 0
        
        TestURLProtocol.onStart = { req in
            guard let url = req.url, url.absoluteString.contains("/pokemon/"), url.absoluteString.hasSuffix("/") else { return }
            lock.lock()
            active += 1
            peak = max(peak, active)
            lock.unlock()
        }
        TestURLProtocol.onFinish = { req in
            guard let url = req.url, url.absoluteString.contains("/pokemon/"), url.absoluteString.hasSuffix("/") else { return }
            lock.lock()
            active -= 1
            lock.unlock()
        }
        
        for id in ids {
            let detail = URL(string: "https://pokeapi.co/api/v2/pokemon/\(id)/")!
            // add a tiny delay so requests overlap
            TestURLProtocol.specs[detail] = .init(status: 200, data: detailJSON(id: id, name: "poke-\(id)"), delay: 0.03)
        }
        
        let done = expect("concurrency capped")
        client.fetchPage(offset: 0, pageSize: ids.count, maxConcurrentDetailLoads: 3)
            .sink(receiveCompletion: { _ in done.fulfill() },
                  receiveValue: { _ in })
            .store(in: &bag)
        
        wait(for: [done], timeout: 3)
        
        XCTAssertLessThanOrEqual(peak, 3, "Detail requests should not exceed the specified concurrency cap")
    }
}

fileprivate class TestURLProtocol: URLProtocol {
    
    struct Spec {
        let status: Int
        let data: Data
        let delay: TimeInterval
    }
    
    static var specs: [URL: Spec] = [:]
    static var onStart: ((URLRequest) -> Void)?
    static var onFinish: ((URLRequest) -> Void)?
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        guard let url = request.url else { return }
        TestURLProtocol.onStart?(request)
        
        let respond = {
            let spec = TestURLProtocol.specs[url] ?? Spec(status: 404, data: Data(), delay: 0)
            let resp = HTTPURLResponse(url: url, statusCode: spec.status, httpVersion: "HTTP/1.1", headerFields: nil)!
            self.client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: spec.data)
            self.client?.urlProtocolDidFinishLoading(self)
            TestURLProtocol.onFinish?(self.request)
        }
        
        if let spec = TestURLProtocol.specs[url], spec.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + spec.delay, execute: respond)
        } else {
            respond()
        }
    }
    
    override func stopLoading() { }
}
