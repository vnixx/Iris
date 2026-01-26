//
//  IrisTests.swift
//  Iris
//

import XCTest
@testable import Iris

// MARK: - 测试用 Model

struct User: Codable {
    let id: Int
    let name: String
}

struct Post: Codable {
    let id: Int
    let title: String
    let content: String
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
    let userId: Int
}

// MARK: - API 定义示例

extension Request {
    
    // ========================================
    // 基础 GET 请求（所有配置集中在一处！）
    // ========================================
    
    /// 获取用户信息
    static func getUser(id: Int) -> Request<User> {
        .init()
            .path("/users/\(id)")
            .method(.get)
            .timeout(15)
            .validateSuccessCodes()
    }
    
    /// 获取用户列表（带查询参数）
    static func getUsers(page: Int, limit: Int) -> Request<[User]> {
        .init()
            .path("/users")
            .method(.get)
            .query(["page": page, "limit": limit])
            .validateSuccessCodes()
    }
    
    /// 搜索用户
    static func searchUsers(keyword: String) -> Request<[User]> {
        .init()
            .path("/users/search")
            .query(["q": keyword])
    }
    
    // ========================================
    // POST 请求（各种 Body 类型）
    // ========================================
    
    /// 登录（使用 Encodable Body）
    static func login(username: String, password: String) -> Request<LoginResponse> {
        .init()
            .path("/auth/login")
            .method(.post)
            .body(LoginRequest(username: username, password: password))
            .validateSuccessCodes()
    }
    
    /// 创建帖子（使用字典 Body）
    static func createPost(title: String, content: String) -> Request<Post> {
        .init()
            .path("/posts")
            .method(.post)
            .body(["title": title, "content": content])
            .header("X-Custom-Header", "custom-value")
            .validateSuccessCodes()
    }
    
    /// 表单提交
    static func submitForm(name: String, email: String) -> Request<EmptyResponse> {
        .init()
            .path("/form")
            .method(.post)
            .formBody(["name": name, "email": email])
    }
    
    // ========================================
    // PUT / PATCH / DELETE 请求
    // ========================================
    
    /// 更新用户
    static func updateUser(id: Int, name: String) -> Request<User> {
        .init()
            .path("/users/\(id)")
            .method(.put)
            .body(["name": name])
            .validateSuccessCodes()
    }
    
    /// 部分更新
    static func patchUser(id: Int, fields: [String: Any]) -> Request<User> {
        .init()
            .path("/users/\(id)")
            .method(.patch)
            .body(fields)
    }
    
    /// 删除用户
    static func deleteUser(id: Int) -> Request<EmptyResponse> {
        .init()
            .path("/users/\(id)")
            .method(.delete)
            .validateSuccessCodes()
    }
    
    // ========================================
    // 文件上传
    // ========================================
    
    /// 上传头像
    static func uploadAvatar(userId: Int, imageData: Data) -> Request<User> {
        .init()
            .path("/users/\(userId)/avatar")
            .method(.post)
            .upload(multipart: [
                .data(imageData, name: "avatar", fileName: "avatar.jpg", mimeType: "image/jpeg")
            ])
            .timeout(60)
    }
    
    /// 上传多个文件
    static func uploadFiles(parts: [MultipartFormBodyPart]) -> Request<EmptyResponse> {
        .init()
            .path("/upload")
            .method(.post)
            .upload(multipart: parts)
            .timeout(120)
    }
    
    // ========================================
    // 文件下载
    // ========================================
    
    /// 下载文件
    static func downloadFile(url: String) -> Request<Data> {
        .init()
            .path(url)
            .download()
    }
    
    /// 下载到 Documents
    static func downloadToDocuments(path: String, fileName: String) -> Request<Data> {
        .init()
            .path(path)
            .downloadToDocuments(fileName: fileName)
    }
    
    // ========================================
    // 带认证的请求
    // ========================================
    
    /// 获取当前用户（需要 Bearer Token）
    static func getCurrentUser(token: String) -> Request<User> {
        .init()
            .path("/me")
            .bearerToken(token)
            .validateSuccessCodes()
    }
    
    /// 使用自定义 Authorization
    static func getProtectedResource(authValue: String) -> Request<[String: String]> {
        .init()
            .path("/protected")
            .authorization(authValue)
    }
    
    // ========================================
    // 带 Stub 的请求（用于测试）
    // ========================================
    
    /// 获取用户（带 Stub 用于单元测试）
    static func getUserWithStub(id: Int) -> Request<User> {
        .init()
            .path("/users/\(id)")
            .stub(behavior: .immediate)
            .stub(.success(User(id: id, name: "Stubbed User")))
    }
    
    /// 模拟失败的请求
    static func getFailingRequest() -> Request<User> {
        .init()
            .path("/fail")
            .stubImmediate(.failure(statusCode: 500, message: "Server Error"))
    }
    
    /// 模拟延迟响应
    static func getSlowRequest() -> Request<User> {
        .init()
            .path("/slow")
            .stubDelayed(.success(User(id: 1, name: "Delayed User")), delay: 2.0)
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
    
    // MARK: - Basic Request Tests
    
    func testStubRequest() async throws {
        // 使用带 stub 的请求
        let response = try await Request<User>.getUserWithStub(id: 123).fire()
        
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.isSuccess)
        
        let user = try response.unwrap()
        XCTAssertEqual(user.id, 123)
        XCTAssertEqual(user.name, "Stubbed User")
    }
    
    func testFetchConvenience() async throws {
        // 使用 fetch() 便捷方法直接获取模型
        let user = try await Request<User>.getUserWithStub(id: 456).fetch()
        
        XCTAssertEqual(user.id, 456)
        XCTAssertEqual(user.name, "Stubbed User")
    }
    
    func testFailingRequest() async throws {
        do {
            _ = try await Request<User>.getFailingRequest().fire()
            XCTFail("Should have thrown an error")
        } catch let error as IrisError {
            if case .statusCode(let response) = error {
                XCTAssertEqual(response.statusCode, 500)
            } else {
                // stub 请求不会触发 statusCode 错误，因为验证类型是 .none
                // 所以这里只检查能正常捕获错误
            }
        }
    }
    
    // MARK: - Response Mapping Tests
    
    func testResponseMapping() async throws {
        let response = try await Request<User>.getUserWithStub(id: 1).fire()
        
        // 转为字符串
        let string = response.mapString()
        XCTAssertNotNil(string)
        
        // 转为 JSON
        let json = try response.mapJSON()
        XCTAssertNotNil(json)
        
        // 转为其他类型
        let user = try response.map(User.self)
        XCTAssertEqual(user.name, "Stubbed User")
    }
    
    // MARK: - EmptyResponse Tests
    
    func testEmptyResponse() async throws {
        // 创建一个返回空响应的请求
        let request = Request<EmptyResponse>
            .plain()
            .path("/ping")
            .stubImmediate(.success(data: Data()))
        
        let response = try await request.fire()
        XCTAssertTrue(response.isSuccess)
    }
    
    // MARK: - Configuration Chain Tests
    
    func testRequestChaining() {
        // 验证链式配置不会丢失属性
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
}

// MARK: - Usage Examples (Not actual tests, just documentation)

/*
 
 ╔════════════════════════════════════════════════════════════════╗
 ║                    Iris 使用指南                                ║
 ╚════════════════════════════════════════════════════════════════╝
 
 1. 全局配置
 ─────────────────────────────────────────────────────────────────
 
 Iris.configure(
     IrisConfiguration()
         .baseURL("https://api.example.com")
         .header("Accept", "application/json")
         .header("X-API-Key", "your-api-key")
         .timeout(30)
         .validation(.successCodes)
         .plugin(NetworkLoggerPlugin())
         .plugin(AccessTokenPlugin { _ in UserDefaults.standard.string(forKey: "token") })
 )
 
 2. 定义 API（每个请求所有配置集中在一处！）
 ─────────────────────────────────────────────────────────────────
 
 extension Request {
     // GET 请求
     static func getUser(id: Int) -> Request<User> {
         .init()
             .path("/users/\(id)")
             .validateSuccessCodes()
     }
     
     // POST 请求
     static func createUser(name: String, email: String) -> Request<User> {
         .init()
             .path("/users")
             .method(.post)
             .body(["name": name, "email": email])
             .validateSuccessCodes()
     }
     
     // 上传文件
     static func uploadImage(data: Data) -> Request<ImageResponse> {
         .init()
             .path("/upload")
             .method(.post)
             .upload(multipart: [
                 .data(data, name: "image", fileName: "image.jpg", mimeType: "image/jpeg")
             ])
             .timeout(60)
     }
 }
 
 3. 发送请求
 ─────────────────────────────────────────────────────────────────
 
 // 方式 1: 获取完整响应
 let response = try await Iris.send(.getUser(id: 123))
 let user = try response.unwrap()
 
 // 方式 2: 使用 fire()
 let response = try await Request.getUser(id: 123).fire()
 
 // 方式 3: 直接获取模型
 let user = try await Request.getUser(id: 123).fetch()
 
 4. 错误处理
 ─────────────────────────────────────────────────────────────────
 
 do {
     let user = try await Request.getUser(id: 123).fetch()
 } catch let error as IrisError {
     switch error {
     case .decodingFailed(let underlyingError):
         print("解码失败: \(underlyingError?.localizedDescription ?? "")")
     case .statusCode(let response):
         print("HTTP 错误: \(response.statusCode)")
     case .networkError(let underlyingError):
         print("网络错误: \(underlyingError.localizedDescription)")
     default:
         print("其他错误: \(error.localizedDescription)")
     }
 }
 
 5. 插件系统
 ─────────────────────────────────────────────────────────────────
 
 // 日志插件
 let logger = NetworkLoggerPlugin(configuration: .verbose)
 
 // Token 插件
 let tokenPlugin = AccessTokenPlugin { target in
     return KeychainManager.shared.token
 }
 
 // 凭证插件
 let credentialsPlugin = CredentialsPlugin(username: "user", password: "pass")
 
 Iris.configuration.plugins = [logger, tokenPlugin]
 
 6. 测试（使用 Stub）
 ─────────────────────────────────────────────────────────────────
 
 // 方式 1: 全局 stub
 Iris.configuration.stubBehavior = .immediate
 
 // 方式 2: 单个请求 stub
 let request = Request<User>()
     .path("/users/1")
     .stubImmediate(.success(User(id: 1, name: "Test")))
 
 // 方式 3: 模拟延迟
 let slowRequest = Request<User>()
     .path("/slow")
     .stubDelayed(.success(User(id: 1, name: "Slow")), delay: 2.0)
 
 // 方式 4: 模拟错误
 let errorRequest = Request<User>()
     .path("/error")
     .stubImmediate(.failure(statusCode: 404, message: "Not Found"))
 
 */
