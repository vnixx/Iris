//
//  IrisError.swift
//  Iris
//

import Foundation

/// Iris 错误类型
public enum IrisError: Error {
    /// 解码失败
    case decodingFailed(Error?)
    
    /// HTTP 错误（状态码验证失败）
    case statusCode(response: HTTPResponse<Data>)
    
    /// 网络错误
    case networkError(Error)
    
    /// 请求映射失败（无法构建 URLRequest）
    case requestMapping(String)
    
    /// 参数编码失败
    case parameterEncodingFailed(reason: ParameterEncodingFailureReason)
    
    /// Encodable 编码失败
    case encodableMapping(Error)
    
    /// 图片映射失败
    case imageMapping(response: HTTPResponse<Data>)
    
    /// JSON 映射失败
    case jsonMapping(response: HTTPResponse<Data>)
    
    /// 字符串映射失败
    case stringMapping(response: HTTPResponse<Data>)
    
    /// 对象映射失败
    case objectMapping(Error, response: HTTPResponse<Data>)
    
    /// 底层错误
    case underlying(Error, response: HTTPResponse<Data>?)
    
    /// 无效的 URL
    case invalidURL(url: String)
    
    /// 缺少 baseURL
    case missingBaseURL
}

// MARK: - Parameter Encoding Failure Reason

public extension IrisError {
    /// 参数编码失败原因
    enum ParameterEncodingFailureReason {
        case missingURL
        case jsonEncodingFailed(Error)
        case customEncodingFailed(Error)
    }
}

// MARK: - Response & Error Accessors

public extension IrisError {
    /// 关联的响应
    var response: HTTPResponse<Data>? {
        switch self {
        case .statusCode(let response):
            return response
        case .imageMapping(let response):
            return response
        case .jsonMapping(let response):
            return response
        case .stringMapping(let response):
            return response
        case .objectMapping(_, let response):
            return response
        case .underlying(_, let response):
            return response
        default:
            return nil
        }
    }
    
    /// 底层错误
    var underlyingError: Error? {
        switch self {
        case .decodingFailed(let error):
            return error
        case .networkError(let error):
            return error
        case .encodableMapping(let error):
            return error
        case .objectMapping(let error, _):
            return error
        case .underlying(let error, _):
            return error
        case .parameterEncodingFailed(let reason):
            switch reason {
            case .jsonEncodingFailed(let error):
                return error
            case .customEncodingFailed(let error):
                return error
            case .missingURL:
                return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - LocalizedError

extension IrisError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .decodingFailed(let error):
            if let error = error {
                return "解码失败: \(error.localizedDescription)"
            }
            return "解码失败"
            
        case .statusCode(let response):
            return "HTTP 状态码错误: \(response.statusCode)"
            
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
            
        case .requestMapping(let url):
            return "无法构建请求: \(url)"
            
        case .parameterEncodingFailed(let reason):
            switch reason {
            case .missingURL:
                return "参数编码失败: 缺少 URL"
            case .jsonEncodingFailed(let error):
                return "JSON 编码失败: \(error.localizedDescription)"
            case .customEncodingFailed(let error):
                return "自定义编码失败: \(error.localizedDescription)"
            }
            
        case .encodableMapping(let error):
            return "Encodable 编码失败: \(error.localizedDescription)"
            
        case .imageMapping:
            return "图片映射失败"
            
        case .jsonMapping:
            return "JSON 映射失败"
            
        case .stringMapping:
            return "字符串映射失败"
            
        case .objectMapping(let error, _):
            return "对象映射失败: \(error.localizedDescription)"
            
        case .underlying(let error, _):
            return "底层错误: \(error.localizedDescription)"
            
        case .invalidURL(let url):
            return "无效的 URL: \(url)"
            
        case .missingBaseURL:
            return "缺少 baseURL 配置"
        }
    }
}

// MARK: - CustomNSError

extension IrisError: CustomNSError {
    public var errorCode: Int {
        switch self {
        case .decodingFailed:
            return 1001
        case .statusCode(let response):
            return response.statusCode
        case .networkError:
            return 1002
        case .requestMapping:
            return 1003
        case .parameterEncodingFailed:
            return 1004
        case .encodableMapping:
            return 1005
        case .imageMapping:
            return 1006
        case .jsonMapping:
            return 1007
        case .stringMapping:
            return 1008
        case .objectMapping:
            return 1009
        case .underlying:
            return 1010
        case .invalidURL:
            return 1011
        case .missingBaseURL:
            return 1012
        }
    }
    
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]
        
        userInfo[NSLocalizedDescriptionKey] = errorDescription
        
        if let underlyingError = underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        
        if let response = response {
            userInfo["statusCode"] = response.statusCode
            userInfo["data"] = response.data
        }
        
        return userInfo
    }
    
    public static var errorDomain: String {
        return "com.iris.error"
    }
}
