//
//  ImageLoaderTests.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 26.10.2025.
//

import XCTest
@testable import Pokemon

final class ImageLoaderTests: XCTestCase {
    var session: URLSession!
    var imageLoader: ImageLoader!
    
    // Register the protocol globally so URLSession.shared uses it.
    override func setUp() {
        super.setUp()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [TestURLProtocol.self]
        session = URLSession(configuration: cfg)
        imageLoader = ImageLoader(session: session)
        TestURLProtocol.specs = [:]
        TestURLProtocol.requestCount = [:]
    }
    
    override func tearDown() {
        imageLoader = nil
        session.invalidateAndCancel()
        session = nil
        TestURLProtocol.specs = [:]
        TestURLProtocol.requestCount = [:]
        super.tearDown()
    }
    
    // Tiny valid 1×1 PNG generator
    private func png1pt() -> Data {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), false, 1)
        UIColor.black.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!.pngData()!
    }
    
    // Make unique URLs per test to avoid cross-test cache bleed
    private func uniqueURL(_ name: String = UUID().uuidString) -> URL {
        URL(string: "https://example.test/\(name).png")!
    }
    
    func test_success_and_caches_on_second_call() async {
        let url = uniqueURL("cache-ok")
        let data = png1pt()
        TestURLProtocol.specs[url] = .init(status: 200, data: data, delay: 1)
        
        // 1st call — network hit
        let img1 = await imageLoader.image(for: url)
        XCTAssertNotNil(img1)
        XCTAssertEqual(TestURLProtocol.requestCount[url], 1)
        
        // 2nd call — should be cache hit (no new network calls)
        let t0 = CFAbsoluteTimeGetCurrent()
        let img2 = await imageLoader.image(for: url)
        let dt = CFAbsoluteTimeGetCurrent() - t0
        
        XCTAssertNotNil(img2)
        XCTAssertEqual(TestURLProtocol.requestCount[url], 1, "Second call should come from cache")
        XCTAssertLessThan(dt, 0.02, "Cached fetch should be very fast")
        
        // Nonisolated accessor reflects cache
        XCTAssertNotNil(imageLoader.cachedImage(for: url))
    }
    
    func test_non200_returns_nil() async {
        let url = uniqueURL("404")
        TestURLProtocol.specs[url] = .init(status: 404, data: Data(), delay: 0)
        
        let img = await imageLoader.image(for: url)
        XCTAssertNil(img)
    }
    
    func test_concurrent_requests_are_coalesced() async {
        let url = uniqueURL("coalesce")
        let data = png1pt()
        // Add a small delay to ensure all requests overlap
        TestURLProtocol.specs[url] = .init(status: 200, data: data, delay: 0.05)
        
        let results: [UIImage?] = await withTaskGroup(of: UIImage?.self, returning: [UIImage?].self) { group in
            for _ in 0..<10 {
                group.addTask { await self.imageLoader.image(for: url) }
            }
            var out: [UIImage?] = []
            for await r in group { out.append(r) }
            return out
        }
        
        XCTAssertTrue(results.allSatisfy { $0 != nil }, "All callers should receive image")
        XCTAssertEqual(TestURLProtocol.requestCount[url], 1, "In-flight dedup should make exactly one HTTP request")
    }
    
    func test_cancellation_doesNotCache() async {
        let url = uniqueURL("cancel")
        let data = png1pt()
        // Longer delay so we can cancel before completion
        TestURLProtocol.specs[url] = .init(status: 200, data: data, delay: 0.25)
        
        let task = Task { await imageLoader.image(for: url) }
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        await imageLoader.cancel(url)
        let img = await task.value
        
        XCTAssertNil(img, "Cancelled path returns nil")
        XCTAssertNil(imageLoader.cachedImage(for: url), "Cancelled downloads must not populate cache")
    }
    
    func test_clearCache_removesCachedImage() async {
        // Given
        let url = uniqueURL("clear-cache")
        let data = png1pt()
        TestURLProtocol.specs[url] = .init(status: 200, data: data, delay: 0)
        
        // Load once → should be cached
        let img1 = await imageLoader.image(for: url)
        XCTAssertNotNil(img1, "Initial image load should succeed")
        XCTAssertNotNil(imageLoader.cachedImage(for: url),
                        "Image should be cached after load")
        
        // When: we clear the cache for that URL
        await imageLoader.clearCache(for: url)
        
        // Then: cachedImage(for:) should now return nil
        let cachedAfterClear = imageLoader.cachedImage(for: url)
        XCTAssertNil(cachedAfterClear, "clearCache(for:) should remove cached image")
        
        // And: a new fetch should trigger a network call again
        let _ = await imageLoader.image(for: url)
        XCTAssertEqual(TestURLProtocol.requestCount[url], 2,
                       "After clearing cache, a new network request should occur")
    }
}

fileprivate class TestURLProtocol: URLProtocol {
    
    struct Spec {
        var status: Int = 200
        var data: Data = Data()
        var delay: TimeInterval = 0
    }
    
    static var specs: [URL: Spec] = [:]
    static var requestCount: [URL: Int] = [:]
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        guard let url = request.url else { return }
        TestURLProtocol.requestCount[url, default: 0] += 1
        
        let respond = {
            let spec = TestURLProtocol.specs[url] ?? Spec(status: 404, data: Data(), delay: 0)
            let resp = HTTPURLResponse(url: url, statusCode: spec.status, httpVersion: "HTTP/1.1", headerFields: nil)!
            self.client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: spec.data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        
        if let spec = TestURLProtocol.specs[url], spec.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + spec.delay, execute: respond)
        } else {
            respond()
        }
    }
    
    override func stopLoading() { }
}
