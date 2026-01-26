//
//  Plugin.swift
//  Iris
//

import Foundation

/// 请求类型协议（用于插件系统）
public protocol RequestType {
    /// 原始 URLRequest
    var urlRequest: URLRequest? { get }
    
    /// 请求标识符
    var requestID: UUID { get }
}

/// 插件协议
public protocol PluginType {
    /// 准备请求（可修改 URLRequest）
    /// - Parameters:
    ///   - request: 原始请求
    ///   - target: 请求配置
    /// - Returns: 修改后的请求
    func prepare(_ request: URLRequest, target: any RequestConfigurable) -> URLRequest
    
    /// 请求即将发送
    /// - Parameters:
    ///   - request: 请求信息
    ///   - target: 请求配置
    func willSend(_ request: RequestType, target: any RequestConfigurable)
    
    /// 收到响应
    /// - Parameters:
    ///   - result: 响应结果
    ///   - target: 请求配置
    func didReceive(_ result: Result<HTTPResponse<Data>, IrisError>, target: any RequestConfigurable)
    
    /// 处理响应（可修改结果）
    /// - Parameters:
    ///   - result: 原始结果
    ///   - target: 请求配置
    /// - Returns: 处理后的结果
    func process(_ result: Result<HTTPResponse<Data>, IrisError>, target: any RequestConfigurable) -> Result<HTTPResponse<Data>, IrisError>
}

// MARK: - Default Implementations

public extension PluginType {
    func prepare(_ request: URLRequest, target: any RequestConfigurable) -> URLRequest {
        return request
    }
    
    func willSend(_ request: RequestType, target: any RequestConfigurable) {}
    
    func didReceive(_ result: Result<HTTPResponse<Data>, IrisError>, target: any RequestConfigurable) {}
    
    func process(_ result: Result<HTTPResponse<Data>, IrisError>, target: any RequestConfigurable) -> Result<HTTPResponse<Data>, IrisError> {
        return result
    }
}

// MARK: - RequestType Implementation

internal struct IrisRequestType: RequestType {
    let urlRequest: URLRequest?
    let requestID: UUID
    
    init(urlRequest: URLRequest?, requestID: UUID = UUID()) {
        self.urlRequest = urlRequest
        self.requestID = requestID
    }
}

// MARK: - RequestConfigurable Protocol

/// 请求配置协议（供插件使用）
public protocol RequestConfigurable {
    var path: String { get }
    var method: Method { get }
    var task: Task { get }
    var headers: [String: String]? { get }
    var timeout: TimeInterval { get }
    var validationType: ValidationType { get }
}
