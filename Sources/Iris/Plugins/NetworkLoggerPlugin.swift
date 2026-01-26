//
//  NetworkLoggerPlugin.swift
//  Iris
//

import Foundation

/// 网络日志插件
public struct NetworkLoggerPlugin: PluginType {
    
    /// 日志配置
    public struct Configuration {
        /// 是否记录请求 Headers
        public var logHeaders: Bool
        
        /// 是否记录请求 Body
        public var logBody: Bool
        
        /// 是否记录响应 Body
        public var logResponseBody: Bool
        
        /// 响应 Body 最大长度（超出截断）
        public var maxResponseBodyLength: Int
        
        /// 自定义日志输出
        public var output: ((String) -> Void)?
        
        /// 日期格式化器
        public var dateFormatter: DateFormatter
        
        public init(
            logHeaders: Bool = true,
            logBody: Bool = true,
            logResponseBody: Bool = true,
            maxResponseBodyLength: Int = 2000,
            output: ((String) -> Void)? = nil
        ) {
            self.logHeaders = logHeaders
            self.logBody = logBody
            self.logResponseBody = logResponseBody
            self.maxResponseBodyLength = maxResponseBodyLength
            self.output = output
            
            self.dateFormatter = DateFormatter()
            self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        }
        
        /// 详细日志配置
        public static var verbose: Configuration {
            Configuration(
                logHeaders: true,
                logBody: true,
                logResponseBody: true,
                maxResponseBodyLength: 5000
            )
        }
        
        /// 简洁日志配置
        public static var concise: Configuration {
            Configuration(
                logHeaders: false,
                logBody: false,
                logResponseBody: false
            )
        }
    }
    
    private let configuration: Configuration
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    public func willSend(_ request: RequestType, target: any RequestConfigurable) {
        var messages: [String] = []
        
        let timestamp = configuration.dateFormatter.string(from: Date())
        
        messages.append("────────────────────────────────────────")
        messages.append("📤 [Iris] Request - \(timestamp)")
        
        if let urlRequest = request.urlRequest {
            messages.append("   URL: \(urlRequest.httpMethod ?? "?") \(urlRequest.url?.absoluteString ?? "?")")
            
            if configuration.logHeaders, let headers = urlRequest.allHTTPHeaderFields, !headers.isEmpty {
                messages.append("   Headers:")
                for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                    // 隐藏敏感信息
                    let displayValue = key.lowercased().contains("authorization") ? "***" : value
                    messages.append("      \(key): \(displayValue)")
                }
            }
            
            if configuration.logBody, let body = urlRequest.httpBody, !body.isEmpty {
                if let bodyString = String(data: body, encoding: .utf8) {
                    messages.append("   Body: \(bodyString)")
                } else {
                    messages.append("   Body: <\(body.count) bytes>")
                }
            }
        }
        
        messages.append("────────────────────────────────────────")
        
        log(messages.joined(separator: "\n"))
    }
    
    public func didReceive(_ result: Result<HTTPResponse<Data>, IrisError>, target: any RequestConfigurable) {
        var messages: [String] = []
        
        let timestamp = configuration.dateFormatter.string(from: Date())
        
        messages.append("────────────────────────────────────────")
        
        switch result {
        case .success(let response):
            let emoji = response.isSuccess ? "✅" : "⚠️"
            messages.append("\(emoji) [Iris] Response - \(timestamp)")
            messages.append("   Status: \(response.statusCode)")
            messages.append("   URL: \(response.request?.url?.absoluteString ?? "?")")
            
            if configuration.logResponseBody, !response.data.isEmpty {
                if let bodyString = String(data: response.data, encoding: .utf8) {
                    let truncated = bodyString.count > configuration.maxResponseBodyLength
                        ? String(bodyString.prefix(configuration.maxResponseBodyLength)) + "... (truncated)"
                        : bodyString
                    messages.append("   Body: \(truncated)")
                } else {
                    messages.append("   Body: <\(response.data.count) bytes>")
                }
            }
            
        case .failure(let error):
            messages.append("❌ [Iris] Error - \(timestamp)")
            messages.append("   Error: \(error.localizedDescription)")
            
            if let response = error.response {
                messages.append("   Status: \(response.statusCode)")
            }
        }
        
        messages.append("────────────────────────────────────────")
        
        log(messages.joined(separator: "\n"))
    }
    
    private func log(_ message: String) {
        if let output = configuration.output {
            output(message)
        } else {
            print(message)
        }
    }
}
