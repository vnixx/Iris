//
//  HTTPResponse.swift
//  Iris
//

import Foundation

/// HTTP 响应封装
public struct HTTPResponse<Model> {
    public let statusCode: Int
    public let data: Data
    public let model: Model?
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    
    public init(
        statusCode: Int,
        data: Data,
        model: Model?,
        request: URLRequest?,
        response: HTTPURLResponse?
    ) {
        self.statusCode = statusCode
        self.data = data
        self.model = model
        self.request = request
        self.response = response
    }
    
    /// 是否成功 (2xx)
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
    
    /// 获取 model，失败时抛出错误
    public func unwrap() throws -> Model {
        guard let model else {
            throw IrisError.decodingFailed(nil)
        }
        return model
    }
    
    /// 重新解码为其他类型
    public func map<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = .init()) throws -> T {
        try decoder.decode(type, from: data)
    }
    
    /// 转为 JSON
    public func mapJSON() throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }
    
    /// 转为字符串
    public func mapString(encoding: String.Encoding = .utf8) -> String? {
        String(data: data, encoding: encoding)
    }
}
