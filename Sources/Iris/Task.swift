//
//  Task.swift
//  Iris
//

import Foundation

/// 请求任务类型
public enum Task {
    /// 无数据请求
    case requestPlain
    
    /// 原始数据请求
    case requestData(Data)
    
    /// JSON 编码对象请求
    case requestJSONEncodable(Encodable)
    
    /// 自定义 JSONEncoder 的 JSON 编码请求
    case requestCustomJSONEncodable(Encodable, encoder: JSONEncoder)
    
    /// URL 参数请求
    case requestParameters(parameters: [String: Any], encoding: ParameterEncoding)
    
    /// 组合请求：URL 参数 + Body 数据
    case requestCompositeData(bodyData: Data, urlParameters: [String: Any])
    
    /// 组合请求：URL 参数 + Body 参数
    case requestCompositeParameters(
        bodyParameters: [String: Any],
        bodyEncoding: ParameterEncoding,
        urlParameters: [String: Any]
    )
    
    /// 文件上传
    case uploadFile(URL)
    
    /// Multipart 表单数据上传
    case uploadMultipart([MultipartFormBodyPart])
    
    /// 组合 Multipart 上传：Multipart 数据 + URL 参数
    case uploadCompositeMultipart([MultipartFormBodyPart], urlParameters: [String: Any])
    
    /// 文件下载
    case downloadDestination(DownloadDestination)
    
    /// 带参数的文件下载
    case downloadParameters(
        parameters: [String: Any],
        encoding: ParameterEncoding,
        destination: DownloadDestination
    )
}

// MARK: - Download Destination

/// 下载文件目标位置
public typealias DownloadDestination = (_ temporaryURL: URL, _ response: HTTPURLResponse) -> (destinationURL: URL, options: DownloadOptions)

/// 下载选项
public struct DownloadOptions: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    /// 如果目标位置已有文件，则移除
    public static let removePreviousFile = DownloadOptions(rawValue: 1 << 0)
    
    /// 如果目录不存在，则创建中间目录
    public static let createIntermediateDirectories = DownloadOptions(rawValue: 1 << 1)
}

// MARK: - Default Download Destinations

public extension Task {
    /// 默认下载目标（临时目录）
    static var defaultDownloadDestination: DownloadDestination {
        { temporaryURL, _ in
            let directoryURL = FileManager.default.temporaryDirectory
            let fileName = temporaryURL.lastPathComponent
            let destinationURL = directoryURL.appendingPathComponent(fileName)
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
    }
    
    /// 下载到 Documents 目录
    static func documentsDownloadDestination(fileName: String? = nil) -> DownloadDestination {
        { temporaryURL, _ in
            let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let name = fileName ?? temporaryURL.lastPathComponent
            let destinationURL = directoryURL.appendingPathComponent(name)
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
    }
    
    /// 下载到 Caches 目录
    static func cachesDownloadDestination(fileName: String? = nil) -> DownloadDestination {
        { temporaryURL, _ in
            let directoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let name = fileName ?? temporaryURL.lastPathComponent
            let destinationURL = directoryURL.appendingPathComponent(name)
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
    }
}
