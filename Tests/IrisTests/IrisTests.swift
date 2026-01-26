//
//  IrisTests.swift
//  Iris
//

import XCTest
@testable import Iris

// MARK: - 测试用 Model

struct User: Decodable {
    let id: Int
    let name: String
}

// MARK: - API 定义示例

extension Request {
    static func getMeetup(
        uid: Int,
        name: String
    ) -> Request<User> {
        .init()
            .method(.get)
            .path("/meetups?uid=\(uid)&name=\(name)")
            .timeout(15)
    }
}

// MARK: - Tests

final class IrisTests: XCTestCase {
    
    func testSendRequest() async throws {
        // 方式1: 获取完整的 HTTPResponse
        let response = try await Iris.send(.getMeetup(uid: 123, name: "phoenix"))
        
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.isSuccess)
        XCTAssertNotNil(response.mapString())
        
        // 获取解码后的 model
        if let user = response.model {
            print("用户: \(user.name)")
        }
        
        // 或者直接 unwrap
        let user = try response.unwrap()
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "phoenix")
    }
    
    func testFireRequest() async throws {
        let response = try await Request<User>.getMeetup(uid: 123, name: "phoenix").fire()
        
        XCTAssertTrue(response.isSuccess)
        let user = try response.unwrap()
        XCTAssertEqual(user.name, "phoenix")
    }
}
