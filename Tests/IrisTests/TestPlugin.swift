//
//  TestPlugin.swift
//  IrisTests
//
//  测试用插件
//

import Foundation
@testable import Iris

/// 测试用插件
final class TestingPlugin: PluginType {
    var request: (RequestType, TargetType)?
    var result: Result<RawResponse, IrisError>?
    var didPrepare = false
    var prepareCalledCount = 0
    var willSendCalledCount = 0
    var didReceiveCalledCount = 0
    var processCalledCount = 0
    
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        prepareCalledCount += 1
        var request = request
        request.addValue("yes", forHTTPHeaderField: "prepared")
        return request
    }
    
    func willSend(_ request: RequestType, target: TargetType) {
        willSendCalledCount += 1
        self.request = (request, target)
        
        // We check for whether or not we did prepare here to make sure prepare gets called
        // before willSend
        didPrepare = request.request?.allHTTPHeaderFields?["prepared"] == "yes"
    }
    
    func didReceive(_ result: Result<RawResponse, IrisError>, target: TargetType) {
        didReceiveCalledCount += 1
        self.result = result
    }
    
    func process(_ result: Result<RawResponse, IrisError>, target: TargetType) -> Result<RawResponse, IrisError> {
        processCalledCount += 1
        var result = result
        
        if case .success(let response) = result {
            let processedResponse = RawResponse(
                statusCode: -1,
                data: response.data,
                request: response.request,
                response: response.response
            )
            result = .success(processedResponse)
        }
        
        return result
    }
    
    func reset() {
        request = nil
        result = nil
        didPrepare = false
        prepareCalledCount = 0
        willSendCalledCount = 0
        didReceiveCalledCount = 0
        processCalledCount = 0
    }
}

/// 记录调用顺序的插件
final class OrderTrackingPlugin: PluginType {
    var callOrder: [String] = []
    
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        callOrder.append("prepare")
        return request
    }
    
    func willSend(_ request: RequestType, target: TargetType) {
        callOrder.append("willSend")
    }
    
    func didReceive(_ result: Result<RawResponse, IrisError>, target: TargetType) {
        callOrder.append("didReceive")
    }
    
    func process(_ result: Result<RawResponse, IrisError>, target: TargetType) -> Result<RawResponse, IrisError> {
        callOrder.append("process")
        return result
    }
    
    func reset() {
        callOrder = []
    }
}

/// 修改请求头的插件
final class HeaderModifyingPlugin: PluginType {
    let headerKey: String
    let headerValue: String
    
    init(headerKey: String, headerValue: String) {
        self.headerKey = headerKey
        self.headerValue = headerValue
    }
    
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var request = request
        request.addValue(headerValue, forHTTPHeaderField: headerKey)
        return request
    }
}

/// 修改响应的插件
final class ResponseModifyingPlugin: PluginType {
    let newStatusCode: Int
    
    init(newStatusCode: Int) {
        self.newStatusCode = newStatusCode
    }
    
    func process(_ result: Result<RawResponse, IrisError>, target: TargetType) -> Result<RawResponse, IrisError> {
        if case .success(let response) = result {
            let modifiedResponse = RawResponse(
                statusCode: newStatusCode,
                data: response.data,
                request: response.request,
                response: response.response
            )
            return .success(modifiedResponse)
        }
        return result
    }
}

/// 错误注入插件
final class ErrorInjectingPlugin: PluginType {
    let error: IrisError
    
    init(error: IrisError) {
        self.error = error
    }
    
    func process(_ result: Result<RawResponse, IrisError>, target: TargetType) -> Result<RawResponse, IrisError> {
        return .failure(error)
    }
}

/// 网络活动追踪插件
final class NetworkActivityPlugin: PluginType {
    enum NetworkActivityChangeType {
        case began
        case ended
    }
    
    typealias NetworkActivityClosure = (_ change: NetworkActivityChangeType, _ target: TargetType) -> Void
    
    let networkActivityClosure: NetworkActivityClosure
    
    init(networkActivityClosure: @escaping NetworkActivityClosure) {
        self.networkActivityClosure = networkActivityClosure
    }
    
    func willSend(_ request: RequestType, target: TargetType) {
        networkActivityClosure(.began, target)
    }
    
    func didReceive(_ result: Result<RawResponse, IrisError>, target: TargetType) {
        networkActivityClosure(.ended, target)
    }
}

/// 空插件（用于测试默认实现）
final class EmptyPlugin: PluginType {
    // 使用默认实现
}
