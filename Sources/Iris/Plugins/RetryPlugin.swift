//
//  RetryPlugin.swift
//  Iris
//

import Foundation

/// 重试策略
public struct RetryPolicy {
    /// 最大重试次数
    public let maxRetryCount: Int
    
    /// 重试延迟（秒）
    public let retryDelay: TimeInterval
    
    /// 指数退避
    public let exponentialBackoff: Bool
    
    /// 可重试的状态码
    public let retryableStatusCodes: Set<Int>
    
    /// 可重试的错误类型
    public let retryableErrorCodes: Set<Int>
    
    public init(
        maxRetryCount: Int = 3,
        retryDelay: TimeInterval = 1.0,
        exponentialBackoff: Bool = true,
        retryableStatusCodes: Set<Int> = [408, 500, 502, 503, 504],
        retryableErrorCodes: Set<Int> = [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorNotConnectedToInternet
        ]
    ) {
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
        self.exponentialBackoff = exponentialBackoff
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableErrorCodes = retryableErrorCodes
    }
    
    /// 默认策略
    public static var `default`: RetryPolicy {
        RetryPolicy()
    }
    
    /// 激进重试策略
    public static var aggressive: RetryPolicy {
        RetryPolicy(
            maxRetryCount: 5,
            retryDelay: 0.5,
            exponentialBackoff: true
        )
    }
    
    /// 保守重试策略
    public static var conservative: RetryPolicy {
        RetryPolicy(
            maxRetryCount: 2,
            retryDelay: 2.0,
            exponentialBackoff: false
        )
    }
    
    /// 计算第 n 次重试的延迟
    public func delay(forRetry retryCount: Int) -> TimeInterval {
        if exponentialBackoff {
            return retryDelay * pow(2.0, Double(retryCount - 1))
        }
        return retryDelay
    }
    
    /// 判断是否可以重试
    public func shouldRetry(statusCode: Int?, error: Error?) -> Bool {
        // 检查状态码
        if let statusCode = statusCode, retryableStatusCodes.contains(statusCode) {
            return true
        }
        
        // 检查错误码
        if let nsError = error as NSError?, retryableErrorCodes.contains(nsError.code) {
            return true
        }
        
        return false
    }
}

/// 重试状态追踪（用于存储重试计数）
/// 注意：这个插件主要用于记录重试意图，实际重试逻辑需要在 Iris.send 中实现
public struct RetryPlugin: PluginType {
    
    private let policy: RetryPolicy
    private let onRetry: ((Int, any RequestConfigurable) -> Void)?
    
    public init(policy: RetryPolicy = .default, onRetry: ((Int, any RequestConfigurable) -> Void)? = nil) {
        self.policy = policy
        self.onRetry = onRetry
    }
    
    public func process(
        _ result: Result<HTTPResponse<Data>, IrisError>,
        target: any RequestConfigurable
    ) -> Result<HTTPResponse<Data>, IrisError> {
        // 这里仅做记录，实际重试需要在 Iris 层实现
        // 因为 Plugin 的 process 方法是同步的，无法执行异步重试
        
        switch result {
        case .success(let response):
            if policy.shouldRetry(statusCode: response.statusCode, error: nil) {
                // 可以在这里记录日志或触发回调
                print("⚠️ [Iris] Status \(response.statusCode) is retryable")
            }
            return result
            
        case .failure(let error):
            if policy.shouldRetry(statusCode: error.response?.statusCode, error: error.underlyingError) {
                print("⚠️ [Iris] Error is retryable: \(error.localizedDescription)")
            }
            return result
        }
    }
}
