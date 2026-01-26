//
//  CredentialsPlugin.swift
//  Iris
//

import Foundation

/// 凭证插件（支持 Basic Auth 等）
public struct CredentialsPlugin: PluginType {
    
    /// 凭证类型
    public enum Credential {
        /// Basic 认证
        case basic(username: String, password: String)
        
        /// 自定义 Header
        case custom(key: String, value: String)
    }
    
    /// 凭证提供闭包
    public typealias CredentialClosure = (any RequestConfigurable) -> Credential?
    
    private let credentialClosure: CredentialClosure
    
    /// 初始化
    /// - Parameter credentialClosure: 提供凭证的闭包
    public init(credentialClosure: @escaping CredentialClosure) {
        self.credentialClosure = credentialClosure
    }
    
    /// 便捷初始化（静态 Basic Auth）
    public init(username: String, password: String) {
        self.credentialClosure = { _ in .basic(username: username, password: password) }
    }
    
    public func prepare(_ request: URLRequest, target: any RequestConfigurable) -> URLRequest {
        guard let credential = credentialClosure(target) else {
            return request
        }
        
        var request = request
        
        switch credential {
        case .basic(let username, let password):
            let credentialData = "\(username):\(password)".data(using: .utf8)!
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            
        case .custom(let key, let value):
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
}
