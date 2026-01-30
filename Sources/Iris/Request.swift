//
//  Request.swift
//  Iris
//
//  Iris 特色：链式构建 Request，所有配置集中在一处
//

import Foundation

/// 网络请求封装（Iris 特色的链式 API）
public struct Request<ResponseType: Decodable>: TargetType {
    
    // MARK: - TargetType Properties
    
    public var baseURL: URL {
        _baseURL ?? Iris.configuration.baseURL ?? URL(string: "https://example.com")!
    }
    
    public var path: String = ""
    
    public var method: Method = .get
    
    public var task: Task = .requestPlain
    
    public var headers: [String: String]?
    
    public var validationType: ValidationType = .none
    
    public var sampleData: Data = Data()
    
    // MARK: - Iris Extended Properties
    
    /// 自定义 baseURL（覆盖全局配置）
    private var _baseURL: URL?
    
    /// 超时时间
    public var timeout: TimeInterval = 30
    
    /// JSON 解码器
    public var decoder: JSONDecoder?
    
    /// Stub 行为（覆盖全局配置）
    public var stubBehavior: StubBehavior?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Basic Configuration (Chainable)
    
    /// 设置请求路径
    public func path(_ path: String) -> Request<ResponseType> {
        var request = self
        request.path = path
        return request
    }
    
    /// 设置 HTTP 方法
    public func method(_ method: Method) -> Request<ResponseType> {
        var request = self
        request.method = method
        return request
    }
    
    /// 设置超时时间
    public func timeout(_ timeout: TimeInterval) -> Request<ResponseType> {
        var request = self
        request.timeout = timeout
        return request
    }
    
    // MARK: - Headers Configuration
    
    /// 设置请求头
    public func headers(_ headers: [String: String]) -> Request<ResponseType> {
        var request = self
        request.headers = headers
        return request
    }
    
    /// 添加单个请求头
    public func header(_ key: String, _ value: String) -> Request<ResponseType> {
        var request = self
        var currentHeaders = request.headers ?? [:]
        currentHeaders[key] = value
        request.headers = currentHeaders
        return request
    }
    
    /// 添加 Authorization Header
    public func authorization(_ value: String) -> Request<ResponseType> {
        header("Authorization", value)
    }
    
    /// 添加 Bearer Token
    public func bearerToken(_ token: String) -> Request<ResponseType> {
        header("Authorization", "Bearer \(token)")
    }
    
    // MARK: - Task Configuration
    
    /// 设置请求任务
    public func task(_ task: Task) -> Request<ResponseType> {
        var request = self
        request.task = task
        return request
    }
    
    /// 设置 URL 参数
    public func query(_ parameters: [String: Any]) -> Request<ResponseType> {
        var request = self
        request.task = .requestParameters(parameters: parameters, encoding: URLEncoding.queryString)
        return request
    }
    
    /// 设置 JSON Body
    public func body(_ parameters: [String: Any]) -> Request<ResponseType> {
        var request = self
        request.task = .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        return request
    }
    
    /// 设置 Encodable Body
    public func body<T: Encodable>(_ encodable: T) -> Request<ResponseType> {
        var request = self
        request.task = .requestJSONEncodable(encodable)
        return request
    }
    
    /// 设置 Encodable Body（自定义 Encoder）
    public func body<T: Encodable>(_ encodable: T, encoder: JSONEncoder) -> Request<ResponseType> {
        var request = self
        request.task = .requestCustomJSONEncodable(encodable, encoder: encoder)
        return request
    }
    
    /// 设置原始 Data Body
    public func body(_ data: Data) -> Request<ResponseType> {
        var request = self
        request.task = .requestData(data)
        return request
    }
    
    /// 设置 Form URL Encoded Body
    public func formBody(_ parameters: [String: Any]) -> Request<ResponseType> {
        var request = self
        request.task = .requestParameters(parameters: parameters, encoding: URLEncoding.httpBody)
        return request
    }
    
    /// 设置组合请求（URL 参数 + Body）
    public func composite(
        query: [String: Any],
        body: [String: Any],
        bodyEncoding: ParameterEncoding = JSONEncoding.default
    ) -> Request<ResponseType> {
        var request = self
        request.task = .requestCompositeParameters(
            bodyParameters: body,
            bodyEncoding: bodyEncoding,
            urlParameters: query
        )
        return request
    }
    
    // MARK: - Upload Configuration
    
    /// 上传文件
    public func upload(file url: URL) -> Request<ResponseType> {
        var request = self
        request.task = .uploadFile(url)
        return request
    }
    
    /// 上传 Multipart 数据
    public func upload(multipart formData: MultipartFormData) -> Request<ResponseType> {
        var request = self
        request.task = .uploadMultipartFormData(formData)
        return request
    }
    
    /// 上传 Multipart 数据（便捷方法）
    public func upload(multipart parts: [MultipartFormBodyPart]) -> Request<ResponseType> {
        var request = self
        request.task = .uploadMultipartFormData(MultipartFormData(parts: parts))
        return request
    }
    
    /// 上传 Multipart 数据（带 URL 参数）
    public func upload(
        multipart formData: MultipartFormData,
        query: [String: Any]
    ) -> Request<ResponseType> {
        var request = self
        request.task = .uploadCompositeMultipartFormData(formData, urlParameters: query)
        return request
    }
    
    // MARK: - Download Configuration
    
    /// 下载文件
    public func download(to destination: @escaping DownloadDestination) -> Request<ResponseType> {
        var request = self
        request.task = .downloadDestination(destination)
        return request
    }
    
    /// 下载文件（带参数）
    public func download(
        parameters: [String: Any],
        encoding: ParameterEncoding = URLEncoding.default,
        to destination: @escaping DownloadDestination
    ) -> Request<ResponseType> {
        var request = self
        request.task = .downloadParameters(parameters: parameters, encoding: encoding, destination: destination)
        return request
    }
    
    // MARK: - Validation Configuration
    
    /// 设置验证类型
    public func validate(_ type: ValidationType) -> Request<ResponseType> {
        var request = self
        request.validationType = type
        return request
    }
    
    /// 验证成功状态码 (2xx)
    public func validateSuccessCodes() -> Request<ResponseType> {
        validate(.successCodes)
    }
    
    /// 验证成功和重定向状态码 (2xx, 3xx)
    public func validateSuccessAndRedirectCodes() -> Request<ResponseType> {
        validate(.successAndRedirectCodes)
    }
    
    /// 验证自定义状态码
    public func validate(statusCodes: [Int]) -> Request<ResponseType> {
        validate(.customCodes(statusCodes))
    }
    
    // MARK: - Other Configuration
    
    /// 设置 baseURL
    public func baseURL(_ url: URL?) -> Request<ResponseType> {
        var request = self
        request._baseURL = url
        return request
    }
    
    /// 设置 baseURL（从字符串）
    public func baseURL(_ urlString: String) -> Request<ResponseType> {
        var request = self
        request._baseURL = URL(string: urlString)
        return request
    }
    
    /// 设置 JSON 解码器
    public func decoder(_ decoder: JSONDecoder) -> Request<ResponseType> {
        var request = self
        request.decoder = decoder
        return request
    }
    
    // MARK: - Stub Configuration
    
    /// 设置 Stub 数据
    public func stub(_ data: Data) -> Request<ResponseType> {
        var request = self
        request.sampleData = data
        return request
    }
    
    /// 设置 Stub 数据（从 Encodable）
    public func stub<T: Encodable>(_ model: T, encoder: JSONEncoder = JSONEncoder()) -> Request<ResponseType> {
        var request = self
        request.sampleData = (try? encoder.encode(model)) ?? Data()
        return request
    }
    
    /// 设置 Stub 数据（从字符串）
    public func stub(_ string: String) -> Request<ResponseType> {
        var request = self
        request.sampleData = string.data(using: .utf8) ?? Data()
        return request
    }
    
    /// 设置 Stub 行为
    public func stub(behavior: StubBehavior) -> Request<ResponseType> {
        var request = self
        request.stubBehavior = behavior
        return request
    }
    
    // MARK: - Execution
    
    /// 发送请求，返回 Response<Model>
    public func fire() async throws -> Response<ResponseType> {
        return try await Iris.send(self)
    }
    
    /// 发送请求并解码为模型
    public func fetch() async throws -> ResponseType {
        return try await Iris.fetch(self)
    }
}

// MARK: - Convenience Static Methods

public extension Request where ResponseType == Empty {
    /// 创建一个不需要响应模型的请求
    static func plain() -> Request<Empty> {
        Request<Empty>()
    }
    
    /// 创建一个 raw 请求（语义更明确）
    static func raw() -> Request<Raw> {
        Request<Raw>()
    }
}

/// Raw 请求类型别名（避免显式泛型）
public typealias RawRequest = Request<Raw>

// MARK: - Empty Response

/// 空响应类型（用于不需要解析响应的请求）
public typealias Raw = Empty
public struct Empty: Decodable {
    public init() {}
    
    public init(from decoder: Decoder) throws {
        // 什么都不做，接受任何响应
    }
}
