//
//  ImageLoader.swift
//  Pokemon
//
//  Created by Hnat Danylevych on 25.10.2025.
//

actor ImageLoader {
    private let session: URLSession
    private static let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    
    init(session: URLSession = .shared) {
        self.session = session
        Self.cache.countLimit = 20
    }
    
    func image(for url: URL) async -> UIImage? {
        let ns = url as NSURL
        
        if let cached = Self.cache.object(forKey: ns) { return cached }
        
        if let t = inFlight[url] { return await t.value }
        
        let task = Task { () -> UIImage? in
            defer { Task { self.cancel(url) } }
            do {
                let (data, resp) = try await session.data(from: url)
                guard (resp as? HTTPURLResponse)?.statusCode == 200,
                      let img = UIImage(data: data) else { return nil }
                guard !Task.isCancelled else { return nil }
                
                Self.cache.setObject(img, forKey: ns)
                return img
            } catch {
                return nil
            }
        }
        
        inFlight[url] = task
        return await task.value
    }
    
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        Self.cache.object(forKey: url as NSURL)
    }
    
    func cancel(_ url: URL) {
        inFlight[url]?.cancel()
        inFlight[url] = nil
    }
    
    func clearCache(for url: URL) {
        Self.cache.removeObject(forKey: url as NSURL)
    }
}
