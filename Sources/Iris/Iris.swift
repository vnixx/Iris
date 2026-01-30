//
//  Iris.swift
//  Iris
//
//  Iris 特色的 async/await 请求发送
//

import Foundation
import Alamofire

/// Iris 网络请求核心
public struct Iris {
    
    /// 发送请求，返回 Response<Model>
    public static func send<Model: Decodable>(_ request: Request<Model>) async throws -> Response<Model> {
        // 检查是否需要 stub
        let stubBehavior = request.stubBehavior ?? configuration.stubBehavior
        if let stubBehavior = stubBehavior {
            return try await performStub(request, behavior: stubBehavior)
        }
        
        // 执行真实请求
        return try await performRequest(request)
    }
    
    /// 发送请求并解码为 Model
    public static func fetch<Model: Decodable>(_ request: Request<Model>) async throws -> Model {
        let response = try await send(request)
        return try response.unwrap()
    }
    
    // MARK: - Private Methods
    
    /// 执行真实网络请求
    private static func performRequest<Model: Decodable>(_ request: Request<Model>) async throws -> Response<Model> {
        // 1. 创建 Endpoint
        let endpoint = createEndpoint(from: request)
        
        // 2. 转换为 URLRequest
        var urlRequest = try endpoint.urlRequest()
        urlRequest.timeoutInterval = request.timeout
        
        // 3. 合并默认 Headers
        var headers = configuration.defaultHeaders
        if let requestHeaders = request.headers {
            headers.merge(requestHeaders) { _, new in new }
        }
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // 4. 创建 interceptor（桥接 Plugin 系统到 Alamofire）
        let interceptor = IrisRequestInterceptor(
            prepare: { urlRequest in
                configuration.plugins.reduce(urlRequest) { $1.prepare($0, target: request) }
            },
            willSend: { urlRequest in
                let requestType = RequestTypeWrapper(request: urlRequest)
                configuration.plugins.forEach { $0.willSend(requestType, target: request) }
            }
        )
        
        // 5. 执行请求
        let rawResponse: RawResponse
        
        switch request.task {
        case .uploadFile(let fileURL):
            rawResponse = try await performUploadFile(urlRequest, fileURL: fileURL, interceptor: interceptor, request: request)
            
        case .uploadMultipartFormData(let formData):
            rawResponse = try await performUploadMultipart(urlRequest, formData: formData, interceptor: interceptor, request: request)
            
        case .uploadCompositeMultipartFormData(let formData, _):
            rawResponse = try await performUploadMultipart(urlRequest, formData: formData, interceptor: interceptor, request: request)
            
        case .downloadDestination(let destination):
            rawResponse = try await performDownload(urlRequest, destination: destination, interceptor: interceptor, request: request)
            
        case .downloadParameters(_, _, let destination):
            rawResponse = try await performDownload(urlRequest, destination: destination, interceptor: interceptor, request: request)
            
        default:
            rawResponse = try await performDataRequest(urlRequest, interceptor: interceptor, request: request)
        }
        
        // 6. 通知插件收到响应
        let result: Result<RawResponse, IrisError> = .success(rawResponse)
        configuration.plugins.forEach { $0.didReceive(result, target: request) }
        
        // 7. 应用插件的 process 方法
        var processedResult = result
        for plugin in configuration.plugins {
            processedResult = plugin.process(processedResult, target: request)
        }
        
        // 8. 解码并返回
        switch processedResult {
        case .success(let rawResponse):
            let model = try decodeModel(Model.self, from: rawResponse, using: request.decoder)
            return Response(
                model: model,
                statusCode: rawResponse.statusCode,
                data: rawResponse.data,
                request: rawResponse.request,
                response: rawResponse.response
            )
        case .failure(let error):
            throw error
        }
    }
    
    /// 解码 Model
    private static func decodeModel<Model: Decodable>(
        _ type: Model.Type,
        from rawResponse: RawResponse,
        using customDecoder: JSONDecoder?
    ) throws -> Model {
        let decoder = customDecoder ?? configuration.jsonDecoder
        
        if Model.self == Empty.self {
            return Empty() as! Model
        }
        
        return try rawResponse.map(Model.self, using: decoder)
    }
    
    /// 创建 Endpoint
    private static func createEndpoint<Model: Decodable>(from request: Request<Model>) -> Endpoint {
        let url = request.baseURL.appendingPathComponent(request.path).absoluteString
        
        return Endpoint(
            url: url,
            sampleResponseClosure: { .networkResponse(200, request.sampleData) },
            method: request.method,
            task: request.task,
            httpHeaderFields: request.headers
        )
    }
    
    /// 执行数据请求
    private static func performDataRequest<Model: Decodable>(
        _ urlRequest: URLRequest,
        interceptor: IrisRequestInterceptor,
        request: Request<Model>
    ) async throws -> RawResponse {
        try await withCheckedThrowingContinuation { continuation in
            let validationCodes = request.validationType.statusCodes
            var afRequest = configuration.session.request(urlRequest, interceptor: interceptor)
            
            if !validationCodes.isEmpty {
                afRequest = afRequest.validate(statusCode: validationCodes)
            }
            
            afRequest.responseData { afResponse in
                switch afResponse.result {
                case .success(let data):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: data,
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(returning: response)
                    
                case .failure(let error):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: afResponse.data ?? Data(),
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    
                    if afResponse.response != nil {
                        continuation.resume(throwing: IrisError.statusCode(response))
                    } else {
                        continuation.resume(throwing: IrisError.underlying(error, response))
                    }
                }
            }
        }
    }
    
    /// 执行文件上传
    private static func performUploadFile<Model: Decodable>(
        _ urlRequest: URLRequest,
        fileURL: URL,
        interceptor: IrisRequestInterceptor,
        request: Request<Model>
    ) async throws -> RawResponse {
        try await withCheckedThrowingContinuation { continuation in
            let validationCodes = request.validationType.statusCodes
            var afRequest = configuration.session.upload(fileURL, with: urlRequest, interceptor: interceptor)
            
            if !validationCodes.isEmpty {
                afRequest = afRequest.validate(statusCode: validationCodes)
            }
            
            afRequest.responseData { afResponse in
                switch afResponse.result {
                case .success(let data):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: data,
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(returning: response)
                    
                case .failure(let error):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: afResponse.data ?? Data(),
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(throwing: IrisError.underlying(error, response))
                }
            }
        }
    }
    
    /// 执行 Multipart 上传
    private static func performUploadMultipart<Model: Decodable>(
        _ urlRequest: URLRequest,
        formData: MultipartFormData,
        interceptor: IrisRequestInterceptor,
        request: Request<Model>
    ) async throws -> RawResponse {
        try await withCheckedThrowingContinuation { continuation in
            let afFormData = RequestMultipartFormData(fileManager: formData.fileManager, boundary: formData.boundary)
            afFormData.applyMoyaMultipartFormData(formData)
            
            let validationCodes = request.validationType.statusCodes
            var afRequest = configuration.session.upload(multipartFormData: afFormData, with: urlRequest, interceptor: interceptor)
            
            if !validationCodes.isEmpty {
                afRequest = afRequest.validate(statusCode: validationCodes)
            }
            
            afRequest.responseData { afResponse in
                switch afResponse.result {
                case .success(let data):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: data,
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(returning: response)
                    
                case .failure(let error):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: afResponse.data ?? Data(),
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(throwing: IrisError.underlying(error, response))
                }
            }
        }
    }
    
    /// 执行下载
    private static func performDownload<Model: Decodable>(
        _ urlRequest: URLRequest,
        destination: @escaping DownloadDestination,
        interceptor: IrisRequestInterceptor,
        request: Request<Model>
    ) async throws -> RawResponse {
        try await withCheckedThrowingContinuation { continuation in
            let validationCodes = request.validationType.statusCodes
            var afRequest = configuration.session.download(urlRequest, interceptor: interceptor, to: destination)
            
            if !validationCodes.isEmpty {
                afRequest = afRequest.validate(statusCode: validationCodes)
            }
            
            afRequest.responseData { afResponse in
                switch afResponse.result {
                case .success(let data):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: data,
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(returning: response)
                    
                case .failure(let error):
                    let response = RawResponse(
                        statusCode: afResponse.response?.statusCode ?? 0,
                        data: afResponse.resumeData ?? Data(),
                        request: afResponse.request,
                        response: afResponse.response
                    )
                    continuation.resume(throwing: IrisError.underlying(error, response))
                }
            }
        }
    }
    
    /// 执行 Stub 请求
    private static func performStub<Model: Decodable>(
        _ request: Request<Model>,
        behavior: StubBehavior
    ) async throws -> Response<Model> {
        // 计算延迟
        let delay: TimeInterval
        switch behavior {
        case .immediate:
            delay = 0
        case .delayed(let interval):
            delay = interval
        }
        
        // 延迟
        if delay > 0 {
            try await _Concurrency.Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // 创建 RawResponse
        let rawResponse = RawResponse(
            statusCode: 200,
            data: request.sampleData,
            request: nil,
            response: nil
        )
        
        // 通知插件
        let requestType = RequestTypeWrapper(request: nil)
        configuration.plugins.forEach { $0.willSend(requestType, target: request) }
        let result: Result<RawResponse, IrisError> = .success(rawResponse)
        configuration.plugins.forEach { $0.didReceive(result, target: request) }
        
        // 应用插件的 process 方法
        var processedResult = result
        for plugin in configuration.plugins {
            processedResult = plugin.process(processedResult, target: request)
        }
        
        switch processedResult {
        case .success(let rawResponse):
            let model = try decodeModel(Model.self, from: rawResponse, using: request.decoder)
            return Response(
                model: model,
                statusCode: rawResponse.statusCode,
                data: rawResponse.data,
                request: rawResponse.request,
                response: rawResponse.response
            )
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - RequestTypeWrapper

/// 简单的 RequestType 包装
private struct RequestTypeWrapper: RequestType {
    let request: URLRequest?
    
    var sessionHeaders: [String: String] { [:] }
    
    func authenticate(username: String, password: String, persistence: URLCredential.Persistence) -> Self {
        self
    }
    
    func authenticate(with credential: URLCredential) -> Self {
        self
    }
    
    func cURLDescription(calling handler: @escaping (String) -> Void) -> Self {
        handler(request?.description ?? "")
        return self
    }
}
