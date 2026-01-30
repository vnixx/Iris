//
//  IrisTests.swift
//  IrisTests
//
//  基础集成测试和 API 使用示例
//

import XCTest
@testable import Iris

// MARK: - 测试用 Model

struct User: Codable, Equatable {
    let id: Int
    let name: String
}

struct Post: Codable {
    let id: Int
    let title: String
    let content: String
}

// MARK: - API 定义示例（Iris 特色：所有配置集中在一处！）

extension Request {
    
    /// 获取用户
    static func getUser(id: Int) -> Request<User> {
        .init()
            .path("/users/\(id)")
            .method(.get)
            .validateSuccessCodes()
    }
    
    /// 获取用户列表
    static func getUsers(page: Int, limit: Int) -> Request<[User]> {
        .init()
            .path("/users")
            .query(["page": page, "limit": limit])
    }
    
    /// 创建用户
    static func createUser(name: String) -> Request<User> {
        .init()
            .path("/users")
            .method(.post)
            .body(["name": name])
            .validateSuccessCodes()
    }
    
    /// 上传头像
    static func uploadAvatar(userId: Int, imageData: Data) -> Request<User> {
        .init()
            .path("/users/\(userId)/avatar")
            .method(.post)
            .upload(multipart: [
                MultipartFormBodyPart(
                    provider: .data(imageData),
                    name: "avatar",
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg"
                )
            ])
            .timeout(60)
    }
    
    /// 带 Stub 的请求（用于测试）
    static func getUserWithStub(id: Int) -> Request<User> {
        .init()
            .path("/users/\(id)")
            .stub(User(id: id, name: "Stubbed User"))
            .stub(behavior: .immediate)
    }
}

// MARK: - Tests

final class IrisTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // 配置全局设置
        Iris.configure(
            IrisConfiguration()
                .baseURL("https://api.example.com")
                .header("Accept", "application/json")
                .timeout(30)
                .stub(.immediate) // 测试时使用 stub
        )
    }
    
    override func tearDown() {
        Iris.configuration = IrisConfiguration()
        super.tearDown()
    }
    
    func testResponse() async throws {
        // fire() 返回 Response<User>
        let response = try await Request<User>.getUserWithStub(id: 123).fire()
        
        // model 是可选的，但 fire() 成功时保证有值
        XCTAssertNotNil(response.model)
        XCTAssertEqual(response.model?.id, 123)
        XCTAssertEqual(response.model?.name, "Stubbed User")
        
        // 使用 unwrap() 获取非可选值
        let user = try response.unwrap()
        XCTAssertEqual(user.id, 123)
        
        // 其他属性
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.isSuccess)
    }
    
    func testFetchConvenience() async throws {
        // fetch() 直接返回 Model（非可选）
        let user = try await Request<User>.getUserWithStub(id: 456).fetch()
        
        XCTAssertEqual(user.id, 456)
        XCTAssertEqual(user.name, "Stubbed User")
    }
    
    func testRequestChaining() {
        let request = Request<User>()
            .path("/test")
            .method(.post)
            .header("X-Custom", "value")
            .body(["key": "value"])
            .timeout(60)
            .validateSuccessCodes()
        
        XCTAssertEqual(request.path, "/test")
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.headers?["X-Custom"], "value")
        XCTAssertEqual(request.timeout, 60)
        XCTAssertEqual(request.validationType, .successCodes)
    }
    
    func testEmpty() async throws {
        let request = Request<Empty>
            .plain()
            .path("/ping")
            .stub(behavior: .immediate)
        
        let response = try await request.fire()
        XCTAssertTrue(response.isSuccess)
    }
    
    func testResponseMapping() async throws {
        let response = try await Request<User>.getUserWithStub(id: 1).fire()
        
        // 转为字符串
        let string = try response.mapString()
        XCTAssertNotNil(string)
        
        // 转为 JSON
        let json = try response.mapJSON()
        XCTAssertNotNil(json)
        
        // 转为其他类型
        let user = try response.map(User.self)
        XCTAssertEqual(user.name, "Stubbed User")
    }
    
    func testResponseConvenienceProperties() async throws {
        let response = try await Request<User>.getUserWithStub(id: 1).fire()
        
        // 测试便利属性
        XCTAssertTrue(response.isSuccess)
        XCTAssertFalse(response.isRedirect)
        XCTAssertFalse(response.isClientError)
        XCTAssertFalse(response.isServerError)
        
        // 过滤状态码
        let filtered = try response.filterSuccessfulStatusCodes()
        XCTAssertEqual(filtered.statusCode, 200)
    }
    
    func testRawResponse() async throws {
        let response = try await Request<User>.getUserWithStub(id: 1).fire()
        
        // 转换为 RawResponse（Response<Never>）
        let raw: RawResponse = response.asRaw()
        XCTAssertEqual(raw.statusCode, 200)
        XCTAssertTrue(raw.isSuccess)
        XCTAssertNil(raw.model)  // RawResponse 的 model 永远是 nil
        
        // RawResponse 也有相同的 mapping 方法
        let user = try raw.map(User.self)
        XCTAssertEqual(user.name, "Stubbed User")
    }
    
    // MARK: - GitHub API Tests (Iris Style - No enum needed!)
    
    func testGitHubZenStub() async throws {
        // Iris 风格：直接构建请求，无需声明 TargetType 枚举
        let response = try await Request<Empty>()
            .baseURL("https://api.github.com")
            .path("/zen")
            .method(.get)
            .stub("Half measures are as bad as nothing at all.".data(using: .utf8)!)
            .stub(behavior: .immediate)
            .fire()
        
        let message = try response.mapString()
        XCTAssertEqual(message, "Half measures are as bad as nothing at all.")
    }
    
    func testGitHubUserProfileStub() async throws {
        // 使用 GitHubAPI 工厂方法（展示 Iris 推荐的 API 封装方式）
        Iris.configure(IrisConfiguration().stub(.immediate))
        
        let response = try await GitHubAPI.userProfile("ashfurrow").fire()
        
        XCTAssertEqual(response.model?.login, "ashfurrow")
        XCTAssertEqual(response.model?.id, 100)
    }
    
    // MARK: - Validation Tests
    
    func testValidationWithSuccessStatusCode() async throws {
        let response = try await Request<User>()
            .path("/users/1")
            .validateSuccessCodes()
            .stub(User(id: 1, name: "Test"))
            .fire()
        
        // Should succeed with 200
        XCTAssertEqual(response.statusCode, 200)
    }
    
    // MARK: - Multiple Plugins Test
    
    func testMultiplePlugins() async throws {
        let plugin1 = TestingPlugin()
        let plugin2 = OrderTrackingPlugin()
        
        Iris.configure(
            IrisConfiguration()
                .baseURL("https://api.example.com")
                .stub(.immediate)
                .plugin(plugin1)
                .plugin(plugin2)
        )
        
        _ = try await Request<User>()
            .path("/users/1")
            .stub(User(id: 1, name: "Test"))
            .fire()
        
        // Both plugins should be called
        // Note: In stub mode, `prepare` is not called (no real URLRequest to prepare)
        // So only willSend, didReceive, and process are called
        XCTAssertEqual(plugin1.willSendCalledCount, 1)
        XCTAssertEqual(plugin1.didReceiveCalledCount, 1)
        XCTAssertEqual(plugin2.callOrder.count, 3) // willSend, didReceive, process (no prepare in stub mode)
        XCTAssertEqual(plugin2.callOrder, ["willSend", "didReceive", "process"])
    }
}

// MARK: - Usage Examples

/*
 
 ╔════════════════════════════════════════════════════════════════╗
 ║               Iris 使用方式                                     ║
 ╚════════════════════════════════════════════════════════════════╝
 
 ## API 定义（每个请求配置集中在一处！）
 
 extension Request {
     static func getUser(id: Int) -> Request<User> {
         .init()
             .path("/users/\(id)")
             .method(.get)
             .validateSuccessCodes()
     }
 }
 
 ## 发送请求
 
 // 方式 1: fire() - 返回 Response<Model>
 let response = try await Request<User>.getUser(id: 123).fire()
 let user = response.model!          // model 是可选的
 let user = try response.unwrap()    // 或者用 unwrap()
 
 // 方式 2: fetch() - 直接返回 Model（推荐）
 let user = try await Request<User>.getUser(id: 123).fetch()
 
 ## 类型结构
 
 - Response<Model>: 带泛型的响应
   - model: Model?（可选，fire() 成功时有值）
   - statusCode, data, isSuccess 等
 - RawResponse = Response<Never>: 无模型响应（用于 Plugin）
 
 */
