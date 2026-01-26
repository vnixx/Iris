//
//  Stub.swift
//  Iris
//

import Foundation

/// Stub 行为
public enum StubBehavior {
    /// 立即返回
    case immediate
    
    /// 延迟返回
    case delayed(TimeInterval)
    
    /// 根据请求决定是否 stub
    case custom((any RequestConfigurable) -> StubBehavior?)
    
    /// 延迟时间
    var delay: TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .delayed(let interval):
            return interval
        case .custom:
            return 0
        }
    }
}

/// Stub 响应
public struct StubResponse {
    /// 状态码
    public let statusCode: Int
    
    /// 响应数据
    public let data: Data
    
    /// 响应头
    public let headers: [String: String]?
    
    /// 错误（如果需要模拟错误）
    public let error: Error?
    
    public init(
        statusCode: Int = 200,
        data: Data = Data(),
        headers: [String: String]? = nil,
        error: Error? = nil
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
        self.error = error
    }
}

// MARK: - Convenience Initializers

public extension StubResponse {
    /// 成功响应（JSON 数据）
    static func success<T: Encodable>(_ model: T, encoder: JSONEncoder = JSONEncoder()) -> StubResponse {
        let data = (try? encoder.encode(model)) ?? Data()
        return StubResponse(statusCode: 200, data: data)
    }
    
    /// 成功响应（字符串）
    static func success(_ string: String) -> StubResponse {
        let data = string.data(using: .utf8) ?? Data()
        return StubResponse(statusCode: 200, data: data)
    }
    
    /// 成功响应（原始数据）
    static func success(data: Data) -> StubResponse {
        StubResponse(statusCode: 200, data: data)
    }
    
    /// 成功响应（从 JSON 文件）
    static func success(jsonFileName: String, in bundle: Bundle = .main) -> StubResponse {
        guard let url = bundle.url(forResource: jsonFileName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return StubResponse(statusCode: 200, data: Data())
        }
        return StubResponse(statusCode: 200, data: data)
    }
    
    /// 错误响应
    static func failure(statusCode: Int, message: String? = nil) -> StubResponse {
        let data = message?.data(using: .utf8) ?? Data()
        return StubResponse(statusCode: statusCode, data: data)
    }
    
    /// 网络错误
    static func networkError(_ error: Error) -> StubResponse {
        StubResponse(statusCode: 0, data: Data(), error: error)
    }
    
    /// 未授权
    static var unauthorized: StubResponse {
        .failure(statusCode: 401, message: "Unauthorized")
    }
    
    /// 未找到
    static var notFound: StubResponse {
        .failure(statusCode: 404, message: "Not Found")
    }
    
    /// 服务器错误
    static var serverError: StubResponse {
        .failure(statusCode: 500, message: "Internal Server Error")
    }
}

// MARK: - Request Sample Data

/// 请求的 Stub 数据协议
public protocol SampleDataProvider {
    /// 模拟响应数据
    var sampleResponse: StubResponse { get }
}

// MARK: - Default Sample Data

public extension SampleDataProvider {
    var sampleResponse: StubResponse {
        StubResponse(statusCode: 200, data: Data())
    }
}
