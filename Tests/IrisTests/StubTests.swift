//
//  StubTests.swift
//  IrisTests
//
//  Integration tests for stub mode.
//

import XCTest
@testable import Iris

final class StubTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Iris.configuration = IrisConfiguration()
            .baseURL("https://api.example.com")
            .stub(.immediate)
    }
    
    override func tearDown() {
        Iris.configuration = IrisConfiguration()
        super.tearDown()
    }
    
    // MARK: - Basic Stub Tests
    
    func testImmediateStubReturnsData() async throws {
        let sampleData = "{\"login\": \"testuser\", \"id\": 123}".data(using: .utf8)!
        
        let response = try await Request<GitHubUser>()
            .path("/users/testuser")
            .stub(sampleData)
            .fire()
        
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.model?.login, "testuser")
        XCTAssertEqual(response.model?.id, 123)
    }
    
    func testStubFromEncodable() async throws {
        let user = GitHubUser(login: "stubuser", id: 456)
        
        let response = try await Request<GitHubUser>()
            .path("/users/stubuser")
            .stub(user)
            .fire()
        
        XCTAssertEqual(response.model?.login, "stubuser")
        XCTAssertEqual(response.model?.id, 456)
    }
    
    func testStubFromString() async throws {
        let response = try await Request<GitHubUser>()
            .path("/users/stringuser")
            .stub("{\"login\": \"stringuser\", \"id\": 789}")
            .fire()
        
        XCTAssertEqual(response.model?.login, "stringuser")
        XCTAssertEqual(response.model?.id, 789)
    }
    
    // MARK: - Delayed Stub Tests
    
    func testDelayedStub() async throws {
        let delay: TimeInterval = 0.5
        let startTime = Date()
        
        let response = try await Request<GitHubUser>()
            .path("/users/delayed")
            .stub(GitHubUser(login: "delayed", id: 1))
            .stub(behavior: .delayed(delay))
            .fire()
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(response.model?.login, "delayed")
        XCTAssertGreaterThanOrEqual(elapsedTime, delay * 0.9) // Allow some tolerance
    }
    
    func testDelayedStubWithGlobalConfiguration() async throws {
        let delay: TimeInterval = 0.3
        Iris.configure(
            IrisConfiguration()
                .baseURL("https://api.example.com")
                .stub(.delayed(delay))
        )
        
        let startTime = Date()
        
        let response = try await Request<GitHubUser>()
            .path("/users/globaldelayed")
            .stub(GitHubUser(login: "globaldelayed", id: 2))
            .fire()
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(response.model?.login, "globaldelayed")
        XCTAssertGreaterThanOrEqual(elapsedTime, delay * 0.9)
    }
    
    // MARK: - Local Stub Override Tests
    
    func testLocalStubBehaviorOverridesGlobal() async throws {
        // Global: delayed
        Iris.configure(
            IrisConfiguration()
                .baseURL("https://api.example.com")
                .stub(.delayed(1.0))
        )
        
        // Local: immediate
        let startTime = Date()
        
        let response = try await Request<GitHubUser>()
            .path("/users/override")
            .stub(GitHubUser(login: "override", id: 3))
            .stub(behavior: .immediate)
            .fire()
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(response.model?.login, "override")
        XCTAssertLessThan(elapsedTime, 0.5) // Should be much faster than 1.0s
    }
    
    // MARK: - Fetch Convenience Tests
    
    func testFetchReturnsModel() async throws {
        let user = try await Request<GitHubUser>()
            .path("/users/fetchuser")
            .stub(GitHubUser(login: "fetchuser", id: 100))
            .fetch()
        
        XCTAssertEqual(user.login, "fetchuser")
        XCTAssertEqual(user.id, 100)
    }
    
    // MARK: - Response Properties Tests
    
    func testStubResponseHasCorrectProperties() async throws {
        let sampleData = "{\"login\": \"propuser\", \"id\": 200}".data(using: .utf8)!
        
        let response = try await Request<GitHubUser>()
            .path("/users/propuser")
            .stub(sampleData)
            .fire()
        
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.isSuccess)
        XCTAssertFalse(response.isRedirect)
        XCTAssertFalse(response.isClientError)
        XCTAssertFalse(response.isServerError)
        XCTAssertEqual(response.data, sampleData)
    }
    
    // MARK: - Empty Response Tests
    
    func testEmptyResponseStub() async throws {
        let response = try await Request<Empty>
            .plain()
            .path("/ping")
            .stub(Data())
            .fire()
        
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.isSuccess)
    }
    
    // MARK: - Array Response Tests
    
    func testArrayResponseStub() async throws {
        let users = [
            GitHubUser(login: "user1", id: 1),
            GitHubUser(login: "user2", id: 2),
            GitHubUser(login: "user3", id: 3)
        ]
        
        let encoder = JSONEncoder()
        let sampleData = try encoder.encode(users)
        
        let response = try await Request<[GitHubUser]>()
            .path("/users")
            .stub(sampleData)
            .fire()
        
        XCTAssertEqual(response.model?.count, 3)
        XCTAssertEqual(response.model?[0].login, "user1")
        XCTAssertEqual(response.model?[1].login, "user2")
        XCTAssertEqual(response.model?[2].login, "user3")
    }
    
    // MARK: - Plugin Integration Tests
    
    func testPluginsAreCalledDuringStub() async throws {
        let plugin = TestingPlugin()
        
        Iris.configure(
            IrisConfiguration()
                .baseURL("https://api.example.com")
                .stub(.immediate)
                .plugin(plugin)
        )
        
        _ = try await Request<GitHubUser>()
            .path("/users/plugintest")
            .stub(GitHubUser(login: "plugintest", id: 1))
            .fire()
        
        XCTAssertEqual(plugin.willSendCalledCount, 1)
        XCTAssertEqual(plugin.didReceiveCalledCount, 1)
        XCTAssertEqual(plugin.processCalledCount, 1)
    }
    
    func testPluginCanModifyStubResponse() async throws {
        let plugin = ResponseModifyingPlugin(newStatusCode: 201)
        
        Iris.configure(
            IrisConfiguration()
                .baseURL("https://api.example.com")
                .stub(.immediate)
                .plugin(plugin)
        )
        
        let response = try await Request<GitHubUser>()
            .path("/users/modified")
            .stub(GitHubUser(login: "modified", id: 1))
            .fire()
        
        // Plugin modifies status code to 201
        XCTAssertEqual(response.statusCode, 201)
    }
    
    // MARK: - Response Mapping Tests
    
    func testStubResponseCanBeFiltered() async throws {
        let response = try await Request<GitHubUser>()
            .path("/users/filter")
            .stub(GitHubUser(login: "filter", id: 1))
            .fire()
        
        // Should not throw since status code is 200
        let filtered = try response.filterSuccessfulStatusCodes()
        XCTAssertEqual(filtered.statusCode, 200)
    }
    
    func testStubResponseCanBeMappedToJSON() async throws {
        let response = try await Request<GitHubUser>()
            .path("/users/json")
            .stub(GitHubUser(login: "json", id: 1))
            .fire()
        
        let json = try response.mapJSON() as? [String: Any]
        XCTAssertEqual(json?["login"] as? String, "json")
        XCTAssertEqual(json?["id"] as? Int, 1)
    }
    
    func testStubResponseCanBeMappedToString() async throws {
        let response = try await Request<GitHubUser>()
            .path("/users/string")
            .stub("{\"login\": \"string\", \"id\": 1}")
            .fire()
        
        let string = try response.mapString()
        XCTAssertTrue(string.contains("string"))
    }
    
    // MARK: - Different Request Methods Tests
    
    func testStubWorksWithPostMethod() async throws {
        let response = try await Request<GitHubUser>()
            .path("/users")
            .method(.post)
            .body(["name": "newuser"])
            .stub(GitHubUser(login: "newuser", id: 999))
            .fire()
        
        XCTAssertEqual(response.model?.login, "newuser")
    }
    
    func testStubWorksWithPutMethod() async throws {
        let response = try await Request<GitHubUser>()
            .path("/users/1")
            .method(.put)
            .body(["name": "updateduser"])
            .stub(GitHubUser(login: "updateduser", id: 1))
            .fire()
        
        XCTAssertEqual(response.model?.login, "updateduser")
    }
    
    func testStubWorksWithDeleteMethod() async throws {
        let response = try await Request<Empty>()
            .path("/users/1")
            .method(.delete)
            .stub(Data())
            .fire()
        
        XCTAssertTrue(response.isSuccess)
    }
    
    // MARK: - Custom Decoder Tests
    
    func testStubWithCustomDecoder() async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let jsonData = "{\"login\": \"customdecoder\", \"id\": 1}".data(using: .utf8)!
        
        let response = try await Request<GitHubUser>()
            .path("/users/customdecoder")
            .stub(jsonData)
            .decoder(decoder)
            .fire()
        
        XCTAssertEqual(response.model?.login, "customdecoder")
    }
}
