//
//  CachePlugin.swift
//  Iris
//

import Foundation

/// 缓存策略
public enum CachePolicy {
    /// 不缓存
    case none
    
    /// 仅使用内存缓存
    case memory(maxAge: TimeInterval)
    
    /// 使用磁盘缓存
    case disk(maxAge: TimeInterval)
    
    /// 内存 + 磁盘缓存
    case memoryAndDisk(memoryMaxAge: TimeInterval, diskMaxAge: TimeInterval)
}

/// 缓存条目
public struct CacheEntry {
    public let data: Data
    public let response: HTTPURLResponse?
    public let timestamp: Date
    public let maxAge: TimeInterval
    
    public var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}

/// 缓存存储协议
public protocol CacheStorage {
    func get(forKey key: String) -> CacheEntry?
    func set(_ entry: CacheEntry, forKey key: String)
    func remove(forKey key: String)
    func removeAll()
}

/// 内存缓存存储
public final class MemoryCacheStorage: CacheStorage {
    private var cache: [String: CacheEntry] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    public func get(forKey key: String) -> CacheEntry? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = cache[key] else { return nil }
        
        // 检查是否过期
        if entry.isExpired {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return entry
    }
    
    public func set(_ entry: CacheEntry, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = entry
    }
    
    public func remove(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }
    
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

/// 缓存插件
/// 注意：缓存插件需要配合 Iris 的缓存逻辑使用
public struct CachePlugin: PluginType {
    
    /// 缓存键生成闭包
    public typealias CacheKeyClosure = (any RequestConfigurable, URLRequest?) -> String?
    
    private let storage: CacheStorage
    private let policy: CachePolicy
    private let cacheKeyClosure: CacheKeyClosure
    
    /// 共享的内存缓存实例
    public static let sharedMemoryStorage = MemoryCacheStorage()
    
    public init(
        storage: CacheStorage = CachePlugin.sharedMemoryStorage,
        policy: CachePolicy = .memory(maxAge: 300),
        cacheKeyClosure: CacheKeyClosure? = nil
    ) {
        self.storage = storage
        self.policy = policy
        self.cacheKeyClosure = cacheKeyClosure ?? { target, request in
            // 默认使用 URL + Method 作为缓存键
            guard let url = request?.url?.absoluteString else { return nil }
            return "\(target.method.rawValue):\(url)"
        }
    }
    
    /// 根据策略获取最大缓存时间
    private var maxAge: TimeInterval {
        switch policy {
        case .none:
            return 0
        case .memory(let maxAge):
            return maxAge
        case .disk(let maxAge):
            return maxAge
        case .memoryAndDisk(let memoryMaxAge, _):
            return memoryMaxAge
        }
    }
    
    public func prepare(_ request: URLRequest, target: any RequestConfigurable) -> URLRequest {
        // 只缓存 GET 请求
        guard target.method == .get else { return request }
        
        // 检查是否有缓存
        if let cacheKey = cacheKeyClosure(target, request),
           let _ = storage.get(forKey: cacheKey) {
            // 标记这个请求可以使用缓存
            var request = request
            request.cachePolicy = .returnCacheDataElseLoad
            return request
        }
        
        return request
    }
    
    public func didReceive(_ result: Result<HTTPResponse<Data>, IrisError>, target: any RequestConfigurable) {
        // 只缓存 GET 请求的成功响应
        guard target.method == .get,
              case .success(let response) = result,
              response.isSuccess,
              maxAge > 0 else { return }
        
        // 生成缓存键
        guard let cacheKey = cacheKeyClosure(target, response.request) else { return }
        
        // 存储缓存
        let entry = CacheEntry(
            data: response.data,
            response: response.response,
            timestamp: Date(),
            maxAge: maxAge
        )
        storage.set(entry, forKey: cacheKey)
    }
    
    /// 获取缓存的响应
    public func getCachedResponse(for request: URLRequest, target: any RequestConfigurable) -> HTTPResponse<Data>? {
        guard let cacheKey = cacheKeyClosure(target, request),
              let entry = storage.get(forKey: cacheKey) else {
            return nil
        }
        
        return HTTPResponse(
            statusCode: entry.response?.statusCode ?? 200,
            data: entry.data,
            model: entry.data,
            request: request,
            response: entry.response
        )
    }
    
    /// 清除所有缓存
    public func clearCache() {
        storage.removeAll()
    }
}
