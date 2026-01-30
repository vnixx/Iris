//
//  Response.swift
//  Iris
//
//  基于 Moya Response，添加泛型支持
//

import Foundation
#if canImport(UIKit)
import UIKit
public typealias Image = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias Image = NSImage
#endif

// MARK: - Response

/// 网络响应
public struct Response<Model>: CustomDebugStringConvertible {
    
    /// 解码后的模型（Plugin 场景为 nil）
    public let model: Model?
    
    /// 状态码
    public let statusCode: Int

    /// 响应数据
    public let data: Data

    /// 原始 URLRequest
    public let request: URLRequest?

    /// HTTPURLResponse 对象
    public let response: HTTPURLResponse?

    public init(model: Model? = nil, statusCode: Int, data: Data, request: URLRequest? = nil, response: HTTPURLResponse? = nil) {
        self.model = model
        self.statusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }

    /// 文本描述
    public var description: String {
        "Status Code: \(statusCode), Data Length: \(data.count)"
    }

    /// 调试描述
    public var debugDescription: String { description }
    
    // MARK: - Model Access
    
    /// 获取 model，如果为 nil 则抛出错误
    public func unwrap() throws -> Model {
        guard let model else {
            throw IrisError.objectMapping(
                NSError(domain: "Iris", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model is nil"]),
                asRaw()
            )
        }
        return model
    }
    
    // MARK: - Convenience Properties
    
    /// 是否成功 (2xx)
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
    
    /// 是否重定向 (3xx)
    public var isRedirect: Bool {
        (300..<400).contains(statusCode)
    }
    
    /// 是否客户端错误 (4xx)
    public var isClientError: Bool {
        (400..<500).contains(statusCode)
    }
    
    /// 是否服务器错误 (5xx)
    public var isServerError: Bool {
        (500..<600).contains(statusCode)
    }
    
    // MARK: - Mapping Methods

    /// 过滤状态码
    public func filter<R: RangeExpression>(statusCodes: R) throws -> Response where R.Bound == Int {
        guard statusCodes.contains(statusCode) else {
            throw IrisError.statusCode(asRaw())
        }
        return self
    }

    /// 过滤指定状态码
    public func filter(statusCode code: Int) throws -> Response {
        try filter(statusCodes: code...code)
    }

    /// 过滤成功状态码 (2xx)
    public func filterSuccessfulStatusCodes() throws -> Response {
        try filter(statusCodes: 200...299)
    }

    /// 过滤成功和重定向状态码 (2xx, 3xx)
    public func filterSuccessfulStatusAndRedirectCodes() throws -> Response {
        try filter(statusCodes: 200...399)
    }

    /// 映射为图片
    public func mapImage() throws -> Image {
        guard let image = Image(data: data) else {
            throw IrisError.imageMapping(asRaw())
        }
        return image
    }

    /// 映射为 JSON
    public func mapJSON(failsOnEmptyData: Bool = true) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        } catch {
            if data.isEmpty && !failsOnEmptyData {
                return NSNull()
            }
            throw IrisError.jsonMapping(asRaw())
        }
    }

    /// 映射为字符串
    public func mapString(atKeyPath keyPath: String? = nil) throws -> String {
        if let keyPath = keyPath {
            guard let jsonDictionary = try mapJSON() as? NSDictionary,
                let string = jsonDictionary.value(forKeyPath: keyPath) as? String else {
                    throw IrisError.stringMapping(asRaw())
            }
            return string
        } else {
            guard let string = String(data: data, encoding: .utf8) else {
                throw IrisError.stringMapping(asRaw())
            }
            return string
        }
    }

    /// 映射为其他 Decodable 类型
    public func map<D: Decodable>(_ type: D.Type, atKeyPath keyPath: String? = nil, using decoder: JSONDecoder = JSONDecoder(), failsOnEmptyData: Bool = true) throws -> D {
        let serializeToData: (Any) throws -> Data? = { (jsonObject) in
            guard JSONSerialization.isValidJSONObject(jsonObject) else {
                return nil
            }
            do {
                return try JSONSerialization.data(withJSONObject: jsonObject)
            } catch {
                throw IrisError.jsonMapping(self.asRaw())
            }
        }
        let jsonData: Data
        keyPathCheck: if let keyPath = keyPath {
            guard let jsonObject = (try mapJSON(failsOnEmptyData: failsOnEmptyData) as? NSDictionary)?.value(forKeyPath: keyPath) else {
                if failsOnEmptyData {
                    throw IrisError.jsonMapping(asRaw())
                } else {
                    jsonData = data
                    break keyPathCheck
                }
            }

            if let data = try serializeToData(jsonObject) {
                jsonData = data
            } else {
                let wrappedJsonObject = ["value": jsonObject]
                let wrappedJsonData: Data
                if let data = try serializeToData(wrappedJsonObject) {
                    wrappedJsonData = data
                } else {
                    throw IrisError.jsonMapping(asRaw())
                }
                do {
                    return try decoder.decode(DecodableWrapper<D>.self, from: wrappedJsonData).value
                } catch let error {
                    throw IrisError.objectMapping(error, asRaw())
                }
            }
        } else {
            jsonData = data
        }
        do {
            if jsonData.isEmpty && !failsOnEmptyData {
                if let emptyJSONObjectData = "{}".data(using: .utf8), let emptyDecodableValue = try? decoder.decode(D.self, from: emptyJSONObjectData) {
                    return emptyDecodableValue
                } else if let emptyJSONArrayData = "[{}]".data(using: .utf8), let emptyDecodableValue = try? decoder.decode(D.self, from: emptyJSONArrayData) {
                    return emptyDecodableValue
                }
            }
            return try decoder.decode(D.self, from: jsonData)
        } catch let error {
            throw IrisError.objectMapping(error, asRaw())
        }
    }
    
    // MARK: - Type Conversion
    
    /// 转换为 RawResponse（无模型）
    public func asRaw() -> RawResponse {
        RawResponse(statusCode: statusCode, data: data, request: request, response: response)
    }
}

// MARK: - RawResponse (typealias)

/// 无模型响应（用于 Plugin）
public typealias RawResponse = Response<Never>

// MARK: - RawResponse Convenience

public extension Response where Model == Never {
    /// 创建 RawResponse
    init(statusCode: Int, data: Data, request: URLRequest? = nil, response: HTTPURLResponse? = nil) {
        self.init(model: nil, statusCode: statusCode, data: data, request: request, response: response)
    }
}

private struct DecodableWrapper<T: Decodable>: Decodable {
    let value: T
}
