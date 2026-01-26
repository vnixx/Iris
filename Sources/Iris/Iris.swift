//
//  Iris.swift
//  Iris
//

import Foundation
import Alamofire

/// Iris 网络请求核心
public struct Iris {
    
    /// 发送请求
    public static func send<Model: Decodable>(_ request: Request<Model>) async throws -> HTTPResponse<Model> {
        // 检查是否需要 stub
        let stubBehavior = request.stubBehavior ?? configuration.stubBehavior
        if let stubBehavior = stubBehavior {
            return try await performStub(request, behavior: stubBehavior)
        }
        
        // 执行真实请求
        return try await performRequest(request)
    }
    
    // MARK: - Private Methods
    
    /// 执行真实网络请求
    private static func performRequest<Model: Decodable>(_ request: Request<Model>) async throws -> HTTPResponse<Model> {
        // 1. 构建 URLRequest
        var urlRequest = try buildURLRequest(from: request)
        
        // 2. 应用插件的 prepare 方法
        for plugin in configuration.plugins {
            urlRequest = plugin.prepare(urlRequest, target: request)
        }
        
        // 3. 通知插件请求即将发送
        let requestType = IrisRequestType(urlRequest: urlRequest)
        for plugin in configuration.plugins {
            plugin.willSend(requestType, target: request)
        }
        
        // 4. 日志
        if configuration.isLoggingEnabled {
            logRequest(urlRequest)
        }
        
        // 5. 执行请求
        let rawResponse: HTTPResponse<Data>
        
        switch request.task {
        case .uploadFile(let fileURL):
            rawResponse = try await performUploadFile(urlRequest, fileURL: fileURL, request: request)
            
        case .uploadMultipart(let parts):
            rawResponse = try await performUploadMultipart(urlRequest, parts: parts, request: request)
            
        case .uploadCompositeMultipart(let parts, _):
            rawResponse = try await performUploadMultipart(urlRequest, parts: parts, request: request)
            
        case .downloadDestination(let destination):
            rawResponse = try await performDownload(urlRequest, destination: destination, request: request)
            
        case .downloadParameters(_, _, let destination):
            rawResponse = try await performDownload(urlRequest, destination: destination, request: request)
            
        default:
            rawResponse = try await performDataRequest(urlRequest, request: request)
        }
        
        // 6. 日志
        if configuration.isLoggingEnabled {
            logResponse(rawResponse)
        }
        
        // 7. 通知插件收到响应
        let result: Result<HTTPResponse<Data>, IrisError> = .success(rawResponse)
        for plugin in configuration.plugins {
            plugin.didReceive(result, target: request)
        }
        
        // 8. 应用插件的 process 方法
        var processedResult = result
        for plugin in configuration.plugins {
            processedResult = plugin.process(processedResult, target: request)
        }
        
        // 9. 处理最终结果
        switch processedResult {
        case .success(let response):
            // 验证状态码
            if !request.validationType.validate(statusCode: response.statusCode) {
                throw IrisError.statusCode(response: response)
            }
            
            // 解码模型
            let decoder = request.decoder ?? configuration.jsonDecoder
            let model: Model?
            
            if Model.self == EmptyResponse.self {
                model = EmptyResponse() as? Model
            } else if response.data.isEmpty {
                model = nil
            } else {
                do {
                    model = try decoder.decode(Model.self, from: response.data)
                } catch {
                    throw IrisError.decodingFailed(error)
                }
            }
            
            return HTTPResponse(
                statusCode: response.statusCode,
                data: response.data,
                model: model,
                request: response.request,
                response: response.response
            )
            
        case .failure(let error):
            throw error
        }
    }
    
    /// 执行数据请求
    private static func performDataRequest<Model: Decodable>(
        _ urlRequest: URLRequest,
        request: Request<Model>
    ) async throws -> HTTPResponse<Data> {
        try await withCheckedThrowingContinuation { continuation in
            AF.request(urlRequest)
                .validate(statusCode: request.validationType.statusCodes)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        let httpResponse = HTTPResponse<Data>(
                            statusCode: response.response?.statusCode ?? 0,
                            data: data,
                            model: data,
                            request: response.request,
                            response: response.response
                        )
                        continuation.resume(returning: httpResponse)
                        
                    case .failure(let error):
                        if let data = response.data, let statusCode = response.response?.statusCode {
                            let httpResponse = HTTPResponse<Data>(
                                statusCode: statusCode,
                                data: data,
                                model: data,
                                request: response.request,
                                response: response.response
                            )
                            continuation.resume(returning: httpResponse)
                        } else {
                            continuation.resume(throwing: IrisError.networkError(error))
                        }
                    }
                }
        }
    }
    
    /// 执行文件上传
    private static func performUploadFile<Model: Decodable>(
        _ urlRequest: URLRequest,
        fileURL: URL,
        request: Request<Model>
    ) async throws -> HTTPResponse<Data> {
        try await withCheckedThrowingContinuation { continuation in
            AF.upload(fileURL, with: urlRequest)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        let httpResponse = HTTPResponse<Data>(
                            statusCode: response.response?.statusCode ?? 0,
                            data: data,
                            model: data,
                            request: response.request,
                            response: response.response
                        )
                        continuation.resume(returning: httpResponse)
                        
                    case .failure(let error):
                        if let data = response.data, let statusCode = response.response?.statusCode {
                            let httpResponse = HTTPResponse<Data>(
                                statusCode: statusCode,
                                data: data,
                                model: data,
                                request: response.request,
                                response: response.response
                            )
                            continuation.resume(returning: httpResponse)
                        } else {
                            continuation.resume(throwing: IrisError.networkError(error))
                        }
                    }
                }
        }
    }
    
    /// 执行 Multipart 上传
    private static func performUploadMultipart<Model: Decodable>(
        _ urlRequest: URLRequest,
        parts: [MultipartFormBodyPart],
        request: Request<Model>
    ) async throws -> HTTPResponse<Data> {
        try await withCheckedThrowingContinuation { continuation in
            AF.upload(multipartFormData: { multipartFormData in
                for part in parts {
                    switch part.provider {
                    case .data(let data):
                        if let fileName = part.fileName, let mimeType = part.mimeType {
                            multipartFormData.append(data, withName: part.name, fileName: fileName, mimeType: mimeType)
                        } else {
                            multipartFormData.append(data, withName: part.name)
                        }
                        
                    case .file(let url):
                        if let fileName = part.fileName, let mimeType = part.mimeType {
                            multipartFormData.append(url, withName: part.name, fileName: fileName, mimeType: mimeType)
                        } else {
                            multipartFormData.append(url, withName: part.name)
                        }
                        
                    case .stream(let stream, let length):
                        let fileName = part.fileName ?? "file"
                        let mimeType = part.mimeType ?? "application/octet-stream"
                        multipartFormData.append(stream, withLength: length, name: part.name, fileName: fileName, mimeType: mimeType)
                    }
                }
            }, with: urlRequest)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    let httpResponse = HTTPResponse<Data>(
                        statusCode: response.response?.statusCode ?? 0,
                        data: data,
                        model: data,
                        request: response.request,
                        response: response.response
                    )
                    continuation.resume(returning: httpResponse)
                    
                case .failure(let error):
                    if let data = response.data, let statusCode = response.response?.statusCode {
                        let httpResponse = HTTPResponse<Data>(
                            statusCode: statusCode,
                            data: data,
                            model: data,
                            request: response.request,
                            response: response.response
                        )
                        continuation.resume(returning: httpResponse)
                    } else {
                        continuation.resume(throwing: IrisError.networkError(error))
                    }
                }
            }
        }
    }
    
    /// 执行下载
    private static func performDownload<Model: Decodable>(
        _ urlRequest: URLRequest,
        destination: @escaping DownloadDestination,
        request: Request<Model>
    ) async throws -> HTTPResponse<Data> {
        try await withCheckedThrowingContinuation { continuation in
            let afDestination: Alamofire.DownloadRequest.Destination = { temporaryURL, response in
                let result = destination(temporaryURL, response)
                var options: Alamofire.DownloadRequest.Options = []
                if result.options.contains(.removePreviousFile) {
                    options.insert(.removePreviousFile)
                }
                if result.options.contains(.createIntermediateDirectories) {
                    options.insert(.createIntermediateDirectories)
                }
                return (result.destinationURL, options)
            }
            
            AF.download(urlRequest, to: afDestination)
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        let httpResponse = HTTPResponse<Data>(
                            statusCode: response.response?.statusCode ?? 0,
                            data: data,
                            model: data,
                            request: response.request,
                            response: response.response
                        )
                        continuation.resume(returning: httpResponse)
                        
                    case .failure(let error):
                        // 下载失败时，data 可能为空
                        let httpResponse = HTTPResponse<Data>(
                            statusCode: response.response?.statusCode ?? 0,
                            data: response.resumeData ?? Data(),
                            model: nil,
                            request: response.request,
                            response: response.response
                        )
                        
                        if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                            continuation.resume(returning: httpResponse)
                        } else {
                            continuation.resume(throwing: IrisError.networkError(error))
                        }
                    }
                }
        }
    }
    
    /// 执行 Stub 请求
    private static func performStub<Model: Decodable>(
        _ request: Request<Model>,
        behavior: StubBehavior
    ) async throws -> HTTPResponse<Model> {
        // 计算延迟
        let delay: TimeInterval
        switch behavior {
        case .immediate:
            delay = 0
        case .delayed(let interval):
            delay = interval
        case .custom(let closure):
            if let customBehavior = closure(request) {
                return try await performStub(request, behavior: customBehavior)
            }
            // 如果 custom 返回 nil，执行真实请求
            return try await performRequest(request)
        }
        
        // 延迟
        if delay > 0 {
            try await _Concurrency.Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // 获取 stub 响应
        let stubResponse = request.sampleResponse
        
        // 检查是否模拟错误
        if let error = stubResponse.error {
            throw IrisError.networkError(error)
        }
        
        // 解码模型
        let decoder = request.decoder ?? configuration.jsonDecoder
        let model: Model?
        
        if Model.self == EmptyResponse.self {
            model = EmptyResponse() as? Model
        } else if stubResponse.data.isEmpty {
            model = nil
        } else {
            do {
                model = try decoder.decode(Model.self, from: stubResponse.data)
            } catch {
                throw IrisError.decodingFailed(error)
            }
        }
        
        return HTTPResponse(
            statusCode: stubResponse.statusCode,
            data: stubResponse.data,
            model: model,
            request: nil,
            response: nil
        )
    }
    
    // MARK: - URL Request Building
    
    /// 构建 URLRequest
    private static func buildURLRequest<Model: Decodable>(from request: Request<Model>) throws -> URLRequest {
        // 获取 baseURL
        guard let baseURL = request.baseURL ?? configuration.baseURL else {
            throw IrisError.missingBaseURL
        }
        
        // 构建完整 URL
        let fullURL: URL
        if request.path.isEmpty {
            fullURL = baseURL
        } else {
            fullURL = baseURL.appendingPathComponent(request.path)
        }
        
        // 创建 URLRequest
        var urlRequest = URLRequest(url: fullURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // 合并 Headers
        var headers = configuration.defaultHeaders
        if let requestHeaders = request.headers {
            headers.merge(requestHeaders) { _, new in new }
        }
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // 根据 Task 类型编码参数
        urlRequest = try encodeTask(request.task, into: urlRequest)
        
        return urlRequest
    }
    
    /// 编码 Task 到 URLRequest
    private static func encodeTask(_ task: Task, into urlRequest: URLRequest) throws -> URLRequest {
        var request = urlRequest
        
        switch task {
        case .requestPlain:
            return request
            
        case .requestData(let data):
            request.httpBody = data
            return request
            
        case .requestJSONEncodable(let encodable):
            return try encodeJSONEncodable(encodable, into: request)
            
        case .requestCustomJSONEncodable(let encodable, let encoder):
            return try encodeJSONEncodable(encodable, into: request, encoder: encoder)
            
        case .requestParameters(let parameters, let encoding):
            return try encoding.encode(request, with: parameters)
            
        case .requestCompositeData(let bodyData, let urlParameters):
            request.httpBody = bodyData
            return try ParameterEncoding.url.encode(request, with: urlParameters)
            
        case .requestCompositeParameters(let bodyParameters, let bodyEncoding, let urlParameters):
            request = try bodyEncoding.encode(request, with: bodyParameters)
            return try ParameterEncoding.url.encode(request, with: urlParameters)
            
        case .uploadFile, .uploadMultipart, .uploadCompositeMultipart:
            // 上传请求的参数由 Alamofire 处理
            return request
            
        case .downloadDestination:
            return request
            
        case .downloadParameters(let parameters, let encoding, _):
            return try encoding.encode(request, with: parameters)
        }
    }
    
    /// 编码 Encodable 到 URLRequest
    private static func encodeJSONEncodable(
        _ encodable: Encodable,
        into request: URLRequest,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> URLRequest {
        var request = request
        
        do {
            let data = try encoder.encode(AnyEncodable(encodable))
            request.httpBody = data
            
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            return request
        } catch {
            throw IrisError.encodableMapping(error)
        }
    }
    
    // MARK: - Logging
    
    private static func logRequest(_ request: URLRequest) {
        print("🌐 [Iris] Request: \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("   Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("   Body: \(bodyString)")
        }
    }
    
    private static func logResponse(_ response: HTTPResponse<Data>) {
        print("✅ [Iris] Response: \(response.statusCode)")
        if let string = response.mapString() {
            let truncated = string.count > 500 ? String(string.prefix(500)) + "..." : string
            print("   Data: \(truncated)")
        }
    }
}

// MARK: - AnyEncodable

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ encodable: Encodable) {
        _encode = encodable.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
