//
//  IrisError.swift
//  Iris
//

import Foundation

public enum IrisError: Error {
    case decodingFailed
    case httpError(statusCode: Int, data: Data)
    case networkError(Error)
}
