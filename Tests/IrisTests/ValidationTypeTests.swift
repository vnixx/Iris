//
//  ValidationTypeTests.swift
//  IrisTests
//
//  ValidationType 相关测试
//

import XCTest
@testable import Iris

final class ValidationTypeTests: XCTestCase {
    
    // MARK: - Status Codes Tests
    
    func testNoneHasEmptyStatusCodes() {
        let validation = ValidationType.none
        XCTAssertTrue(validation.statusCodes.isEmpty)
    }
    
    func testSuccessCodesContains200To299() {
        let validation = ValidationType.successCodes
        let statusCodes = validation.statusCodes
        
        XCTAssertEqual(statusCodes.count, 100)
        XCTAssertTrue(statusCodes.contains(200))
        XCTAssertTrue(statusCodes.contains(299))
        XCTAssertFalse(statusCodes.contains(300))
        XCTAssertFalse(statusCodes.contains(199))
    }
    
    func testSuccessAndRedirectCodesContains200To399() {
        let validation = ValidationType.successAndRedirectCodes
        let statusCodes = validation.statusCodes
        
        XCTAssertEqual(statusCodes.count, 200)
        XCTAssertTrue(statusCodes.contains(200))
        XCTAssertTrue(statusCodes.contains(299))
        XCTAssertTrue(statusCodes.contains(300))
        XCTAssertTrue(statusCodes.contains(399))
        XCTAssertFalse(statusCodes.contains(400))
        XCTAssertFalse(statusCodes.contains(199))
    }
    
    func testCustomCodesReturnsGivenCodes() {
        let customCodes = [200, 201, 204, 400, 404]
        let validation = ValidationType.customCodes(customCodes)
        
        XCTAssertEqual(validation.statusCodes, customCodes)
    }
    
    // MARK: - Equality Tests
    
    func testNoneEqualsNone() {
        XCTAssertEqual(ValidationType.none, ValidationType.none)
    }
    
    func testSuccessCodesEqualsSuccessCodes() {
        XCTAssertEqual(ValidationType.successCodes, ValidationType.successCodes)
    }
    
    func testSuccessAndRedirectCodesEqualsSuccessAndRedirectCodes() {
        XCTAssertEqual(ValidationType.successAndRedirectCodes, ValidationType.successAndRedirectCodes)
    }
    
    func testCustomCodesEqualsCustomCodesWithSameValues() {
        let codes1 = ValidationType.customCodes([200, 201])
        let codes2 = ValidationType.customCodes([200, 201])
        XCTAssertEqual(codes1, codes2)
    }
    
    func testCustomCodesNotEqualsCustomCodesWithDifferentValues() {
        let codes1 = ValidationType.customCodes([200, 201])
        let codes2 = ValidationType.customCodes([200, 202])
        XCTAssertNotEqual(codes1, codes2)
    }
    
    func testDifferentTypesAreNotEqual() {
        XCTAssertNotEqual(ValidationType.none, ValidationType.successCodes)
        XCTAssertNotEqual(ValidationType.successCodes, ValidationType.successAndRedirectCodes)
        XCTAssertNotEqual(ValidationType.none, ValidationType.customCodes([]))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyCustomCodes() {
        let validation = ValidationType.customCodes([])
        XCTAssertTrue(validation.statusCodes.isEmpty)
    }
    
    func testSingleCustomCode() {
        let validation = ValidationType.customCodes([200])
        XCTAssertEqual(validation.statusCodes, [200])
    }
    
    func testCustomCodesOrderIsPreserved() {
        let codes = [404, 200, 500, 201]
        let validation = ValidationType.customCodes(codes)
        XCTAssertEqual(validation.statusCodes, codes)
    }
    
    func testCustomCodesDuplicatesArePreserved() {
        let codes = [200, 200, 201]
        let validation = ValidationType.customCodes(codes)
        XCTAssertEqual(validation.statusCodes, codes)
    }
}
