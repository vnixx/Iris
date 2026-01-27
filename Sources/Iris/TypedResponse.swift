//
//  TypedResponse.swift
//  Iris
//
//  带泛型的响应封装，结合 Moya Response 和自动解码
//

import Foundation

/// 带泛型的响应（Iris 特色）
public struct TypedResponse<Model> {
    
    /// 已解码的模型
    public let model: Model
    
    /// 原始 Response（与 Moya 兼容）
    public let rawResponse: Response
    
    public init(model: Model, rawResponse: Response) {
        self.model = model
        self.rawResponse = rawResponse
    }
    
    // MARK: - Response Properties (Forwarded)
    
    /// 状态码
    public var statusCode: Int { rawResponse.statusCode }
    
    /// 原始数据
    public var data: Data { rawResponse.data }
    
    /// 原始 URLRequest
    public var request: URLRequest? { rawResponse.request }
    
    /// HTTPURLResponse
    public var response: HTTPURLResponse? { rawResponse.response }
    
    /// 是否成功 (2xx)
    public var isSuccess: Bool { rawResponse.isSuccess }
    
    /// 是否重定向 (3xx)
    public var isRedirect: Bool { rawResponse.isRedirect }
    
    /// 是否客户端错误 (4xx)
    public var isClientError: Bool { rawResponse.isClientError }
    
    /// 是否服务器错误 (5xx)
    public var isServerError: Bool { rawResponse.isServerError }
    
    // MARK: - Additional Mapping
    
    /// 重新解码为其他类型
    public func map<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = .init()) throws -> T {
        try rawResponse.map(type, using: decoder)
    }
    
    /// 转为 JSON
    public func mapJSON() throws -> Any {
        try rawResponse.mapJSON()
    }
    
    /// 转为字符串
    public func mapString() throws -> String {
        try rawResponse.mapString()
    }
}
