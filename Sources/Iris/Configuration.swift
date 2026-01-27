//
//  Configuration.swift
//  Iris
//

import Foundation
import Alamofire

/// Iris 全局配置
public struct IrisConfiguration {
    /// 基础 URL
    public var baseURL: URL?
    
    /// 默认请求头
    public var defaultHeaders: [String: String]
    
    /// 默认超时时间
    public var defaultTimeout: TimeInterval
    
    /// JSON 解码器
    public var jsonDecoder: JSONDecoder
    
    /// JSON 编码器
    public var jsonEncoder: JSONEncoder
    
    /// 插件列表
    public var plugins: [PluginType]
    
    /// 自定义 Alamofire Session
    public var session: Session
    
    /// Stub 行为（nil 表示正常请求）
    public var stubBehavior: StubBehavior?
    
    public init(
        baseURL: URL? = nil,
        defaultHeaders: [String: String] = [:],
        defaultTimeout: TimeInterval = 30,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder(),
        plugins: [PluginType] = [],
        session: Session = Session.default,
        stubBehavior: StubBehavior? = nil
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.defaultTimeout = defaultTimeout
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.plugins = plugins
        self.session = session
        self.stubBehavior = stubBehavior
    }
}

// MARK: - Global Configuration

public extension Iris {
    /// 全局默认配置
    static var configuration = IrisConfiguration()
    
    /// 配置 Iris
    static func configure(_ configuration: IrisConfiguration) {
        self.configuration = configuration
    }
}

// MARK: - Configuration Builder

public extension IrisConfiguration {
    /// 链式设置 baseURL
    func baseURL(_ url: URL?) -> IrisConfiguration {
        var config = self
        config.baseURL = url
        return config
    }
    
    /// 链式设置 baseURL（从字符串）
    func baseURL(_ urlString: String) -> IrisConfiguration {
        var config = self
        config.baseURL = URL(string: urlString)
        return config
    }
    
    /// 链式添加默认 Header
    func header(_ key: String, _ value: String) -> IrisConfiguration {
        var config = self
        config.defaultHeaders[key] = value
        return config
    }
    
    /// 链式设置默认 Headers
    func headers(_ headers: [String: String]) -> IrisConfiguration {
        var config = self
        config.defaultHeaders.merge(headers) { _, new in new }
        return config
    }
    
    /// 链式设置超时
    func timeout(_ timeout: TimeInterval) -> IrisConfiguration {
        var config = self
        config.defaultTimeout = timeout
        return config
    }
    
    /// 链式添加插件
    func plugin(_ plugin: PluginType) -> IrisConfiguration {
        var config = self
        config.plugins.append(plugin)
        return config
    }
    
    /// 链式设置多个插件
    func plugins(_ plugins: [PluginType]) -> IrisConfiguration {
        var config = self
        config.plugins.append(contentsOf: plugins)
        return config
    }
    
    /// 链式设置 Session
    func session(_ session: Session) -> IrisConfiguration {
        var config = self
        config.session = session
        return config
    }
    
    /// 链式设置 Stub 行为
    func stub(_ behavior: StubBehavior) -> IrisConfiguration {
        var config = self
        config.stubBehavior = behavior
        return config
    }
    
    /// 链式设置 JSON Decoder
    func decoder(_ decoder: JSONDecoder) -> IrisConfiguration {
        var config = self
        config.jsonDecoder = decoder
        return config
    }
    
    /// 链式设置 JSON Encoder
    func encoder(_ encoder: JSONEncoder) -> IrisConfiguration {
        var config = self
        config.jsonEncoder = encoder
        return config
    }
}

// MARK: - Stub Behavior

/// Stub 行为
public enum StubBehavior {
    /// 立即返回
    case immediate
    
    /// 延迟返回
    case delayed(TimeInterval)
}
