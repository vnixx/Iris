//
//  ParameterEncoding.swift
//  Iris
//

import Foundation

/// 参数编码方式
public enum ParameterEncoding {
    /// URL 编码（用于 GET 请求或 URL 查询参数）
    case url
    
    /// URL 编码到请求 Body
    case urlEncodedBody
    
    /// JSON 编码
    case json
    
    /// JSON 编码（自定义 JSONEncoder）
    case customJSON(JSONEncoder)
    
    /// 自定义编码
    case custom((URLRequest, [String: Any]) throws -> URLRequest)
    
    /// 编码参数到请求
    public func encode(_ urlRequest: URLRequest, with parameters: [String: Any]?) throws -> URLRequest {
        guard let parameters = parameters, !parameters.isEmpty else {
            return urlRequest
        }
        
        var request = urlRequest
        
        switch self {
        case .url:
            return try encodeURL(request, with: parameters)
            
        case .urlEncodedBody:
            return try encodeURLBody(request, with: parameters)
            
        case .json:
            return try encodeJSON(request, with: parameters, encoder: JSONEncoder())
            
        case .customJSON(let encoder):
            return try encodeJSON(request, with: parameters, encoder: encoder)
            
        case .custom(let closure):
            return try closure(request, parameters)
        }
    }
    
    // MARK: - Private Encoding Methods
    
    private func encodeURL(_ request: URLRequest, with parameters: [String: Any]) throws -> URLRequest {
        var request = request
        
        guard let url = request.url else {
            throw IrisError.parameterEncodingFailed(reason: .missingURL)
        }
        
        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let percentEncodedQuery = (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(from: parameters)
            urlComponents.percentEncodedQuery = percentEncodedQuery
            request.url = urlComponents.url
        }
        
        return request
    }
    
    private func encodeURLBody(_ request: URLRequest, with parameters: [String: Any]) throws -> URLRequest {
        var request = request
        
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        
        request.httpBody = query(from: parameters).data(using: .utf8)
        
        return request
    }
    
    private func encodeJSON(_ request: URLRequest, with parameters: [String: Any], encoder: JSONEncoder) throws -> URLRequest {
        var request = request
        
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            throw IrisError.parameterEncodingFailed(reason: .jsonEncodingFailed(error))
        }
        
        return request
    }
    
    // MARK: - Query String Building
    
    private func query(from parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted() {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    
    private func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []
        
        switch value {
        case let dictionary as [String: Any]:
            for (nestedKey, nestedValue) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: nestedValue)
            }
        case let array as [Any]:
            for element in array {
                components += queryComponents(fromKey: "\(key)[]", value: element)
            }
        case let bool as Bool:
            components.append((escape(key), escape(bool ? "true" : "false")))
        case let number as NSNumber:
            components.append((escape(key), escape("\(number)")))
        default:
            components.append((escape(key), escape("\(value)")))
        }
        
        return components
    }
    
    private func escape(_ string: String) -> String {
        // RFC 3986 unreserved characters
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
    }
}
