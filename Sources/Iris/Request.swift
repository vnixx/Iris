//
//  Request.swift
//  Iris
//

import Foundation

/// 网络请求封装
public struct Request<ResponseModel: Decodable>: RequestConfigurable, SampleDataProvider {
    // MARK: - Properties
    
    public var path: String = ""
    public var method: Method = .get
    public var task: Task = .requestPlain
    public var headers: [String: String]?
    public var timeout: TimeInterval = 30
    public var validationType: ValidationType = .none
    
    /// 自定义 baseURL（覆盖全局配置）
    public var baseURL: URL?
    
    /// JSON 解码器
    public var decoder: JSONDecoder?
    
    /// Stub 响应数据（用于测试）
    public var sampleResponse: StubResponse = StubResponse()
    
    /// Stub 行为（覆盖全局配置，nil 使用全局配置）
    public var stubBehavior: StubBehavior?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Basic Configuration (Chainable)
    
    /// 设置请求路径
    public func path(_ path: String) -> Request<ResponseModel> {
        var request = self
        request.path = path
        return request
    }
    
    /// 设置 HTTP 方法
    public func method(_ method: Method) -> Request<ResponseModel> {
        var request = self
        request.method = method
        return request
    }
    
    /// 设置超时时间
    public func timeout(_ timeout: TimeInterval) -> Request<ResponseModel> {
        var request = self
        request.timeout = timeout
        return request
    }
    
    // MARK: - Headers Configuration
    
    /// 设置请求头
    public func headers(_ headers: [String: String]) -> Request<ResponseModel> {
        var request = self
        request.headers = headers
        return request
    }
    
    /// 添加单个请求头
    public func header(_ key: String, _ value: String) -> Request<ResponseModel> {
        var request = self
        var currentHeaders = request.headers ?? [:]
        currentHeaders[key] = value
        request.headers = currentHeaders
        return request
    }
    
    /// 添加 Authorization Header
    public func authorization(_ value: String) -> Request<ResponseModel> {
        header("Authorization", value)
    }
    
    /// 添加 Bearer Token
    public func bearerToken(_ token: String) -> Request<ResponseModel> {
        header("Authorization", "Bearer \(token)")
    }
    
    /// 添加 Content-Type Header
    public func contentType(_ value: String) -> Request<ResponseModel> {
        header("Content-Type", value)
    }
    
    // MARK: - Task Configuration
    
    /// 设置请求任务
    public func task(_ task: Task) -> Request<ResponseModel> {
        var request = self
        request.task = task
        return request
    }
    
    /// 设置 URL 参数
    public func query(_ parameters: [String: Any]) -> Request<ResponseModel> {
        var request = self
        request.task = .requestParameters(parameters: parameters, encoding: .url)
        return request
    }
    
    /// 设置 JSON Body
    public func body(_ parameters: [String: Any]) -> Request<ResponseModel> {
        var request = self
        request.task = .requestParameters(parameters: parameters, encoding: .json)
        return request
    }
    
    /// 设置 Encodable Body
    public func body<T: Encodable>(_ encodable: T) -> Request<ResponseModel> {
        var request = self
        request.task = .requestJSONEncodable(encodable)
        return request
    }
    
    /// 设置 Encodable Body（自定义 Encoder）
    public func body<T: Encodable>(_ encodable: T, encoder: JSONEncoder) -> Request<ResponseModel> {
        var request = self
        request.task = .requestCustomJSONEncodable(encodable, encoder: encoder)
        return request
    }
    
    /// 设置原始 Data Body
    public func body(_ data: Data) -> Request<ResponseModel> {
        var request = self
        request.task = .requestData(data)
        return request
    }
    
    /// 设置 Form URL Encoded Body
    public func formBody(_ parameters: [String: Any]) -> Request<ResponseModel> {
        var request = self
        request.task = .requestParameters(parameters: parameters, encoding: .urlEncodedBody)
        return request
    }
    
    /// 设置组合请求（URL 参数 + Body）
    public func composite(
        query: [String: Any],
        body: [String: Any],
        bodyEncoding: ParameterEncoding = .json
    ) -> Request<ResponseModel> {
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
    public func upload(file url: URL) -> Request<ResponseModel> {
        var request = self
        request.task = .uploadFile(url)
        return request
    }
    
    /// 上传 Multipart 数据
    public func upload(multipart parts: [MultipartFormBodyPart]) -> Request<ResponseModel> {
        var request = self
        request.task = .uploadMultipart(parts)
        return request
    }
    
    /// 上传 Multipart 数据（带 URL 参数）
    public func upload(
        multipart parts: [MultipartFormBodyPart],
        query: [String: Any]
    ) -> Request<ResponseModel> {
        var request = self
        request.task = .uploadCompositeMultipart(parts, urlParameters: query)
        return request
    }
    
    // MARK: - Download Configuration
    
    /// 下载文件
    public func download(to destination: @escaping DownloadDestination) -> Request<ResponseModel> {
        var request = self
        request.task = .downloadDestination(destination)
        return request
    }
    
    /// 下载文件（带参数）
    public func download(
        parameters: [String: Any],
        encoding: ParameterEncoding = .url,
        to destination: @escaping DownloadDestination
    ) -> Request<ResponseModel> {
        var request = self
        request.task = .downloadParameters(parameters: parameters, encoding: encoding, destination: destination)
        return request
    }
    
    /// 下载到默认位置
    public func download() -> Request<ResponseModel> {
        download(to: Task.defaultDownloadDestination)
    }
    
    /// 下载到 Documents 目录
    public func downloadToDocuments(fileName: String? = nil) -> Request<ResponseModel> {
        download(to: Task.documentsDownloadDestination(fileName: fileName))
    }
    
    /// 下载到 Caches 目录
    public func downloadToCaches(fileName: String? = nil) -> Request<ResponseModel> {
        download(to: Task.cachesDownloadDestination(fileName: fileName))
    }
    
    // MARK: - Validation Configuration
    
    /// 设置验证类型
    public func validate(_ type: ValidationType) -> Request<ResponseModel> {
        var request = self
        request.validationType = type
        return request
    }
    
    /// 验证成功状态码 (2xx)
    public func validateSuccessCodes() -> Request<ResponseModel> {
        validate(.successCodes)
    }
    
    /// 验证成功和重定向状态码 (2xx, 3xx)
    public func validateSuccessAndRedirectCodes() -> Request<ResponseModel> {
        validate(.successAndRedirectCodes)
    }
    
    /// 验证自定义状态码
    public func validate(statusCodes: [Int]) -> Request<ResponseModel> {
        validate(.customCodes(statusCodes))
    }
    
    /// 验证状态码范围
    public func validate(statusCode range: ClosedRange<Int>) -> Request<ResponseModel> {
        validate(.range(range))
    }
    
    // MARK: - Other Configuration
    
    /// 设置 baseURL
    public func baseURL(_ url: URL?) -> Request<ResponseModel> {
        var request = self
        request.baseURL = url
        return request
    }
    
    /// 设置 baseURL（从字符串）
    public func baseURL(_ urlString: String) -> Request<ResponseModel> {
        var request = self
        request.baseURL = URL(string: urlString)
        return request
    }
    
    /// 设置 JSON 解码器
    public func decoder(_ decoder: JSONDecoder) -> Request<ResponseModel> {
        var request = self
        request.decoder = decoder
        return request
    }
    
    // MARK: - Stub Configuration
    
    /// 设置 Stub 响应
    public func stub(_ response: StubResponse) -> Request<ResponseModel> {
        var request = self
        request.sampleResponse = response
        return request
    }
    
    /// 设置 Stub 行为
    public func stub(behavior: StubBehavior) -> Request<ResponseModel> {
        var request = self
        request.stubBehavior = behavior
        return request
    }
    
    /// 启用立即 Stub
    public func stubImmediate(_ response: StubResponse) -> Request<ResponseModel> {
        var request = self
        request.sampleResponse = response
        request.stubBehavior = .immediate
        return request
    }
    
    /// 启用延迟 Stub
    public func stubDelayed(_ response: StubResponse, delay: TimeInterval) -> Request<ResponseModel> {
        var request = self
        request.sampleResponse = response
        request.stubBehavior = .delayed(delay)
        return request
    }
    
    // MARK: - Execution
    
    /// 发送请求
    public func fire() async throws -> HTTPResponse<ResponseModel> {
        return try await Iris.send(self)
    }
    
    /// 发送请求并获取模型
    public func fetch() async throws -> ResponseModel {
        let response = try await fire()
        return try response.unwrap()
    }
}

// MARK: - Convenience Static Methods

public extension Request where ResponseModel == EmptyResponse {
    /// 创建一个不需要响应模型的请求
    static func plain() -> Request<EmptyResponse> {
        Request<EmptyResponse>()
    }
}

// MARK: - Empty Response

/// 空响应类型（用于不需要解析响应的请求）
public struct EmptyResponse: Decodable {
    public init() {}
    
    public init(from decoder: Decoder) throws {
        // 什么都不做，接受任何响应
    }
}
