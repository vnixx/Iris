//
//  AccessTokenPlugin.swift
//  Iris
//

import Foundation

/// Token 类型
public enum AuthorizationType: String {
    case basic = "Basic"
    case bearer = "Bearer"
    case custom = ""
    
    public var value: String? {
        switch self {
        case .basic, .bearer:
            return rawValue
        case .custom:
            return nil
        }
    }
}

/// Token 提供者协议
public protocol AccessTokenAuthorizable {
    /// 认证类型
    var authorizationType: AuthorizationType? { get }
}

/// 默认实现
public extension AccessTokenAuthorizable {
    var authorizationType: AuthorizationType? {
        return .bearer
    }
}

/// Access Token 插件
public struct AccessTokenPlugin: PluginType {
    
    /// Token 提供闭包
    public typealias TokenClosure = (any RequestConfigurable) -> String?
    
    private let tokenClosure: TokenClosure
    
    /// 初始化
    /// - Parameter tokenClosure: 提供 token 的闭包
    public init(tokenClosure: @escaping TokenClosure) {
        self.tokenClosure = tokenClosure
    }
    
    /// 便捷初始化（静态 token）
    public init(token: String) {
        self.tokenClosure = { _ in token }
    }
    
    public func prepare(_ request: URLRequest, target: any RequestConfigurable) -> URLRequest {
        guard let token = tokenClosure(target), !token.isEmpty else {
            return request
        }
        
        var request = request
        
        // 确定认证类型
        let authType: AuthorizationType
        if let authorizable = target as? AccessTokenAuthorizable,
           let type = authorizable.authorizationType {
            authType = type
        } else {
            authType = .bearer
        }
        
        // 构建 Authorization 值
        let authValue: String
        if let prefix = authType.value, !prefix.isEmpty {
            authValue = "\(prefix) \(token)"
        } else {
            authValue = token
        }
        
        request.setValue(authValue, forHTTPHeaderField: "Authorization")
        
        return request
    }
}

// MARK: - RequestConfigurable + AccessTokenAuthorizable

/// 让 Request 支持自定义认证类型
extension Request: AccessTokenAuthorizable {
    /// 默认使用 Bearer
    public var authorizationType: AuthorizationType? {
        return .bearer
    }
}
