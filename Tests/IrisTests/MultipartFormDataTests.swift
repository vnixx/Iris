//
//  MultipartFormDataTests.swift
//  IrisTests
//
//  Tests for MultipartFormData and MultipartFormBodyPart.
//

import XCTest
@testable import Iris

final class MultipartFormDataTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testMultipartFormDataInitializesCorrectly() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")
        let bodyPart = MultipartFormBodyPart(
            provider: .file(fileURL),
            name: "MyName",
            fileName: "test.txt",
            mimeType: "text/plain"
        )
        let data = MultipartFormData(parts: [bodyPart])
        
        XCTAssertNil(data.boundary)
        XCTAssertEqual(data.fileManager, FileManager.default)
        XCTAssertEqual(data.parts.count, 1)
        XCTAssertEqual(data.parts[0].name, "MyName")
        XCTAssertEqual(data.parts[0].fileName, "test.txt")
        XCTAssertEqual(data.parts[0].mimeType, "text/plain")
        
        if case .file(let url) = data.parts[0].provider {
            XCTAssertEqual(url, fileURL)
        } else {
            XCTFail("The provider was not initialized correctly.")
        }
    }
    
    func testMultipartFormDataWithCustomBoundary() {
        let data = MultipartFormData(
            boundary: "custom-boundary",
            parts: []
        )
        
        XCTAssertEqual(data.boundary, "custom-boundary")
    }
    
    func testMultipartFormDataWithCustomFileManager() {
        let customFileManager = FileManager()
        let data = MultipartFormData(
            fileManager: customFileManager,
            parts: []
        )
        
        XCTAssertTrue(data.fileManager === customFileManager)
    }
    
    // MARK: - FormDataProvider Tests
    
    func testFormDataProviderData() {
        let testData = "test content".data(using: .utf8)!
        let bodyPart = MultipartFormBodyPart(
            provider: .data(testData),
            name: "content"
        )
        
        if case .data(let data) = bodyPart.provider {
            XCTAssertEqual(data, testData)
        } else {
            XCTFail("Expected data provider")
        }
    }
    
    func testFormDataProviderFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/file.txt")
        let bodyPart = MultipartFormBodyPart(
            provider: .file(fileURL),
            name: "file"
        )
        
        if case .file(let url) = bodyPart.provider {
            XCTAssertEqual(url, fileURL)
        } else {
            XCTFail("Expected file provider")
        }
    }
    
    func testFormDataProviderStream() {
        let inputStream = InputStream(data: Data())
        let length: UInt64 = 1024
        let bodyPart = MultipartFormBodyPart(
            provider: .stream(inputStream, length),
            name: "stream"
        )
        
        if case .stream(let stream, let streamLength) = bodyPart.provider {
            XCTAssertNotNil(stream)
            XCTAssertEqual(streamLength, length)
        } else {
            XCTFail("Expected stream provider")
        }
    }
    
    // MARK: - MultipartFormBodyPart Tests
    
    func testBodyPartWithAllProperties() {
        let data = "image data".data(using: .utf8)!
        let bodyPart = MultipartFormBodyPart(
            provider: .data(data),
            name: "avatar",
            fileName: "avatar.jpg",
            mimeType: "image/jpeg"
        )
        
        XCTAssertEqual(bodyPart.name, "avatar")
        XCTAssertEqual(bodyPart.fileName, "avatar.jpg")
        XCTAssertEqual(bodyPart.mimeType, "image/jpeg")
    }
    
    func testBodyPartWithMinimalProperties() {
        let data = "content".data(using: .utf8)!
        let bodyPart = MultipartFormBodyPart(
            provider: .data(data),
            name: "field"
        )
        
        XCTAssertEqual(bodyPart.name, "field")
        XCTAssertNil(bodyPart.fileName)
        XCTAssertNil(bodyPart.mimeType)
    }
    
    // MARK: - ExpressibleByArrayLiteral Tests
    
    func testExpressibleByArrayLiteral() {
        let part1 = MultipartFormBodyPart(provider: .data(Data()), name: "part1")
        let part2 = MultipartFormBodyPart(provider: .data(Data()), name: "part2")
        
        let formData: MultipartFormData = [part1, part2]
        
        XCTAssertEqual(formData.parts.count, 2)
        XCTAssertEqual(formData.parts[0].name, "part1")
        XCTAssertEqual(formData.parts[1].name, "part2")
    }
    
    // MARK: - Hashable Tests
    
    func testMultipartFormDataHashable() {
        let data1 = MultipartFormData(parts: [
            MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "field")
        ])
        let data2 = MultipartFormData(parts: [
            MultipartFormBodyPart(provider: .data("test".data(using: .utf8)!), name: "field")
        ])
        
        XCTAssertEqual(data1, data2)
        XCTAssertEqual(data1.hashValue, data2.hashValue)
    }
    
    func testMultipartFormDataNotEqualWithDifferentParts() {
        let data1 = MultipartFormData(parts: [
            MultipartFormBodyPart(provider: .data("test1".data(using: .utf8)!), name: "field")
        ])
        let data2 = MultipartFormData(parts: [
            MultipartFormBodyPart(provider: .data("test2".data(using: .utf8)!), name: "field")
        ])
        
        XCTAssertNotEqual(data1, data2)
    }
    
    func testMultipartFormBodyPartHashable() {
        let part1 = MultipartFormBodyPart(
            provider: .data("test".data(using: .utf8)!),
            name: "field",
            fileName: "test.txt",
            mimeType: "text/plain"
        )
        let part2 = MultipartFormBodyPart(
            provider: .data("test".data(using: .utf8)!),
            name: "field",
            fileName: "test.txt",
            mimeType: "text/plain"
        )
        
        XCTAssertEqual(part1, part2)
        XCTAssertEqual(part1.hashValue, part2.hashValue)
    }
    
    // MARK: - Multiple Parts Tests
    
    func testMultipleParts() {
        let textPart = MultipartFormBodyPart(
            provider: .data("text content".data(using: .utf8)!),
            name: "text"
        )
        let filePart = MultipartFormBodyPart(
            provider: .file(URL(fileURLWithPath: "/tmp/file.txt")),
            name: "file",
            fileName: "file.txt",
            mimeType: "text/plain"
        )
        let imagePart = MultipartFormBodyPart(
            provider: .data(testImageData),
            name: "image",
            fileName: "image.png",
            mimeType: "image/png"
        )
        
        let formData = MultipartFormData(parts: [textPart, filePart, imagePart])
        
        XCTAssertEqual(formData.parts.count, 3)
        XCTAssertEqual(formData.parts[0].name, "text")
        XCTAssertEqual(formData.parts[1].name, "file")
        XCTAssertEqual(formData.parts[2].name, "image")
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyMultipartFormData() {
        let formData = MultipartFormData(parts: [])
        
        XCTAssertEqual(formData.parts.count, 0)
        XCTAssertNil(formData.boundary)
        XCTAssertEqual(formData.fileManager, FileManager.default)
    }
    
    func testEmptyDataProvider() {
        let bodyPart = MultipartFormBodyPart(
            provider: .data(Data()),
            name: "empty"
        )
        
        if case .data(let data) = bodyPart.provider {
            XCTAssertTrue(data.isEmpty)
        } else {
            XCTFail("Expected data provider")
        }
    }
}
