//
//  Request.swift
//  Iris
//

import Foundation

public struct Request<ResponseModel: Decodable> {
    public var path: String = ""
    public var method: Method = .get
    public var timeout: TimeInterval = 10
    
    public init() {}
    
    public func path(_ path: String) -> Request<ResponseModel> {
        var request = self
        request.path = path
        return request
    }
    
    public func method(_ method: Method) -> Request<ResponseModel> {
        var request = self
        request.method = method
        return request
    }
    
    public func timeout(_ timeout: TimeInterval) -> Request<ResponseModel> {
        var request = self
        request.timeout = timeout
        return request
    }
    
    public func fire() async throws -> HTTPResponse<ResponseModel> {
        return try await Iris.send(self)
    }
}
