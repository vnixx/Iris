//
//  TestHelpers.swift
//  IrisTests
//
//  测试辅助类和模拟数据
//

import Foundation
@testable import Iris

// MARK: - API Factories (Iris Style)

/// GitHub API 请求工厂 - 展示 Iris 链式 API 的使用方式
enum GitHubAPI {
    static let baseURL = "https://api.github.com"
    
    /// 获取 Zen 格言
    static func zen() -> Request<String> {
        Request<String>()
            .baseURL(baseURL)
            .path("/zen")
            .method(.get)
            .stub("Half measures are as bad as nothing at all.")
    }
    
    /// 获取用户资料
    static func userProfile(_ name: String) -> Request<GitHubUser> {
        Request<GitHubUser>()
            .baseURL(baseURL)
            .path("/users/\(name.urlEscaped)")
            .method(.get)
            .stub(GitHubUser(login: name, id: 100))
            .validateSuccessAndRedirectCodes()
    }
}

/// HTTPBin API 请求工厂
enum HTTPBinAPI {
    static let baseURL = "http://httpbin.org"
    
    /// Basic Auth 请求
    static func basicAuth() -> Request<AuthResponse> {
        Request<AuthResponse>()
            .baseURL(baseURL)
            .path("/basic-auth/user/passwd")
            .method(.get)
            .stub(AuthResponse(authenticated: true, user: "user"))
    }
    
    /// POST 请求
    static func post() -> Request<HTTPBinResponse> {
        Request<HTTPBinResponse>()
            .baseURL(baseURL)
            .path("/post")
            .method(.post)
            .stub(HTTPBinResponse.empty)
    }
    
    /// 文件上传
    static func upload(file: URL) -> Request<HTTPBinResponse> {
        Request<HTTPBinResponse>()
            .baseURL(baseURL)
            .path("/post")
            .method(.post)
            .upload(file: file)
            .stub(HTTPBinResponse.empty)
    }
    
    /// Multipart 上传
    static func uploadMultipart(
        parts: [MultipartFormBodyPart],
        urlParameters: [String: Any]? = nil
    ) -> Request<HTTPBinResponse> {
        var request = Request<HTTPBinResponse>()
            .baseURL(baseURL)
            .path("/post")
            .method(.post)
            .stub(HTTPBinResponse.empty)
        
        if let urlParameters = urlParameters {
            request = request.upload(multipart: MultipartFormData(parts: parts), query: urlParameters)
        } else {
            request = request.upload(multipart: MultipartFormData(parts: parts))
        }
        
        return request
    }
    
    /// 带验证的上传
    static func validatedUpload(
        parts: [MultipartFormBodyPart],
        urlParameters: [String: Any]? = nil,
        codes: [Int]
    ) -> Request<HTTPBinResponse> {
        var request = uploadMultipart(parts: parts, urlParameters: urlParameters)
        request = request.validate(.customCodes(codes))
        return request
    }
    
    /// 创建测试用的 multipart 数据
    static func createTestMultipartFormData() -> [MultipartFormBodyPart] {
        let string = "some data"
        guard let data = string.data(using: .utf8) else {
            fatalError("Failed creating Data from String \(string)")
        }
        return [
            MultipartFormBodyPart(provider: .data(data), name: "data")
        ]
    }
}

/// GitHub UserContent API 请求工厂
enum GitHubUserContentAPI {
    static let baseURL = "https://raw.githubusercontent.com"
    
    /// 下载 Moya Web 内容
    static func downloadMoyaWebContent(_ contentPath: String) -> Request<Data> {
        Request<Data>()
            .baseURL(baseURL)
            .path("/Moya/Moya/master/web/\(contentPath)")
            .method(.get)
            .download(to: defaultDownloadDestination)
            .stub(Data(count: 4000))
    }
    
    /// 请求 Moya Web 内容
    static func requestMoyaWebContent(_ contentPath: String) -> Request<Data> {
        Request<Data>()
            .baseURL(baseURL)
            .path("/Moya/Moya/master/web/\(contentPath)")
            .method(.get)
            .stub(Data(count: 4000))
    }
}

private let defaultDownloadDestination: DownloadDestination = { temporaryURL, response in
    let directoryURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    
    if !directoryURLs.isEmpty {
        return (directoryURLs.first!.appendingPathComponent(response.suggestedFilename!), [])
    }
    
    return (temporaryURL, [])
}

// MARK: - Response Models

/// HTTPBin 认证响应
struct AuthResponse: Codable, Equatable {
    let authenticated: Bool
    let user: String
}

/// HTTPBin 响应
struct HTTPBinResponse: Codable, Equatable {
    let args: [String: String]
    let data: String
    let files: [String: String]
    let form: [String: String]
    
    static let empty = HTTPBinResponse(args: [:], data: "", files: [:], form: [:])
}

// MARK: - String Helpers

extension String {
    var urlEscaped: String {
        self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
}

// MARK: - URL Helpers

extension URL {
    static func random(withExtension ext: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
        let name = UUID().uuidString + "." + ext
        return directory.appendingPathComponent(name, isDirectory: false)
    }
}

// MARK: - Test Fixtures

/// A fixture for testing Decodable mapping
struct Issue: Codable, Equatable {
    let title: String
    let createdAt: Date
    let rating: Float?
    
    enum CodingKeys: String, CodingKey {
        case title
        case createdAt
        case rating
    }
}

/// A fixture for testing optional Decodable mapping
struct OptionalIssue: Codable {
    let title: String?
    let createdAt: Date?
}

/// GitHub User fixture
struct GitHubUser: Codable, Equatable {
    let login: String
    let id: Int
}

// MARK: - Simple Endpoint Factory

/// 创建简单的测试 Endpoint（用于 Endpoint 类的单元测试）
func makeSimpleEndpoint(
    url: String = "https://api.github.com/zen",
    method: HTTPMethod = .get,
    task: Task = .requestPlain,
    sampleData: Data = "Half measures are as bad as nothing at all.".data(using: .utf8)!,
    headers: [String: String]? = ["Title": "Dominar"]
) -> Endpoint {
    Endpoint(
        url: url,
        sampleResponseClosure: { .networkResponse(200, sampleData) },
        method: method,
        task: task,
        httpHeaderFields: headers
    )
}

/// 创建失败的 Endpoint
func makeFailureEndpoint(url: String = "https://api.github.com/zen") -> Endpoint {
    let error = NSError(domain: "com.iris.iriserror", code: 0, userInfo: [NSLocalizedDescriptionKey: "Houston, we have a problem"])
    return Endpoint(
        url: url,
        sampleResponseClosure: { .networkError(error) },
        method: .get,
        task: .requestPlain,
        httpHeaderFields: nil
    )
}

// MARK: - Test Image Data

let testImageData: Data = {
    // Create a simple 1x1 PNG image
    // PNG header + minimal IHDR + IDAT + IEND
    let pngData: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, // IHDR length
        0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x00, 0x01, // width
        0x00, 0x00, 0x00, 0x01, // height
        0x08, 0x02, // bit depth, color type
        0x00, 0x00, 0x00, // compression, filter, interlace
        0x90, 0x77, 0x53, 0xDE, // CRC
        0x00, 0x00, 0x00, 0x0C, // IDAT length
        0x49, 0x44, 0x41, 0x54, // IDAT
        0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x00,
        0x05, 0xFE, 0x02, 0xFE,
        0xA3, 0x6E, 0x93, 0x9C, // CRC
        0x00, 0x00, 0x00, 0x00, // IEND length
        0x49, 0x45, 0x4E, 0x44, // IEND
        0xAE, 0x42, 0x60, 0x82  // CRC
    ]
    return Data(pngData)
}()

// MARK: - DispatchQueue Test Helpers

extension DispatchQueue {
    class var currentLabel: String? {
        String(validatingUTF8: __dispatch_queue_get_label(nil))
    }
}
