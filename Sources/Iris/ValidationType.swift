//
//  ValidationType.swift
//  Iris
//

import Foundation

/// 响应验证类型
public enum ValidationType {
    /// 不验证状态码
    case none
    
    /// 仅验证成功状态码 (2xx)
    case successCodes
    
    /// 验证成功和重定向状态码 (2xx, 3xx)
    case successAndRedirectCodes
    
    /// 自定义状态码范围
    case customCodes([Int])
    
    /// 自定义状态码范围（使用 Range）
    case range(ClosedRange<Int>)
    
    /// 验证状态码是否有效
    public func validate(statusCode: Int) -> Bool {
        switch self {
        case .none:
            return true
        case .successCodes:
            return (200..<300).contains(statusCode)
        case .successAndRedirectCodes:
            return (200..<400).contains(statusCode)
        case .customCodes(let codes):
            return codes.contains(statusCode)
        case .range(let range):
            return range.contains(statusCode)
        }
    }
    
    /// 获取有效的状态码集合（用于 Alamofire）
    public var statusCodes: [Int] {
        switch self {
        case .none:
            return Array(100..<600)
        case .successCodes:
            return Array(200..<300)
        case .successAndRedirectCodes:
            return Array(200..<400)
        case .customCodes(let codes):
            return codes
        case .range(let range):
            return Array(range)
        }
    }
}

// MARK: - Equatable

extension ValidationType: Equatable {
    public static func == (lhs: ValidationType, rhs: ValidationType) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.successCodes, .successCodes):
            return true
        case (.successAndRedirectCodes, .successAndRedirectCodes):
            return true
        case (.customCodes(let lCodes), .customCodes(let rCodes)):
            return lCodes == rCodes
        case (.range(let lRange), .range(let rRange)):
            return lRange == rRange
        default:
            return false
        }
    }
}
