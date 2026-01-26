//
//  Iris.swift
//  Iris
//

import Foundation

public struct Iris {
    public static func send<Model: Decodable>(_ request: Request<Model>) async throws -> HTTPResponse<Model> {
        print("requesting: \(request.path)")
        
        // TODO: 实现真实的网络请求
        // 模拟网络请求
        let data = """
        {"id": 1, "name": "phoenix"}
        """.data(using: .utf8)!
        
        let statusCode = 200
        let model = try? JSONDecoder().decode(Model.self, from: data)
        
        return HTTPResponse(
            statusCode: statusCode,
            data: data,
            model: model,
            request: nil,
            response: nil
        )
    }
}
