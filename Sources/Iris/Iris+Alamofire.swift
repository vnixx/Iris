//
//  Iris+Alamofire.swift
//  Iris
//
//  Copied from Moya (Moya+Alamofire.swift)
//

import Foundation
import Alamofire

public typealias Session = Alamofire.Session
internal typealias AFRequest = Alamofire.Request
internal typealias AFDownloadRequest = Alamofire.DownloadRequest
internal typealias AFUploadRequest = Alamofire.UploadRequest
internal typealias AFDataRequest = Alamofire.DataRequest

internal typealias URLRequestConvertible = Alamofire.URLRequestConvertible

/// Represents an HTTP method.
public typealias Method = Alamofire.HTTPMethod

/// Choice of parameter encoding.
public typealias ParameterEncoding = Alamofire.ParameterEncoding
public typealias JSONEncoding = Alamofire.JSONEncoding
public typealias URLEncoding = Alamofire.URLEncoding

/// Multipart form.
public typealias RequestMultipartFormData = Alamofire.MultipartFormData

/// Multipart form data encoding result.
public typealias DownloadDestination = Alamofire.DownloadRequest.Destination

/// Represents Request interceptor type that can modify/act on Request
public typealias RequestInterceptor = Alamofire.RequestInterceptor

/// Make the Alamofire Request type conform to our type, to prevent leaking Alamofire to plugins.
extension AFRequest: RequestType {
    // Note: AFRequest already has a `request` property, so we don't need to implement it
    
    public var sessionHeaders: [String: String] {
        delegate?.sessionConfiguration.httpAdditionalHeaders as? [String: String] ?? [:]
    }
}

// MARK: - URLRequest Encoding Extensions

internal extension URLRequest {
    func encoded(encodable: Encodable, encoder: JSONEncoder = JSONEncoder()) throws -> URLRequest {
        do {
            let encodableWrapper = AnyEncodable(encodable)
            let data = try encoder.encode(encodableWrapper)
            var request = self
            request.httpBody = data
            
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            return request
        } catch {
            throw IrisError.encodableMapping(error)
        }
    }
    
    func encoded(parameters: [String: Any], parameterEncoding: ParameterEncoding) throws -> URLRequest {
        do {
            return try parameterEncoding.encode(self, with: parameters)
        } catch {
            throw IrisError.parameterEncoding(error)
        }
    }
}

// MARK: - AnyEncodable

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ encodable: Encodable) {
        _encode = encodable.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - CancellableToken

/// Internal token that can be used to cancel requests
public final class CancellableToken: Cancellable, CustomDebugStringConvertible {
    let cancelAction: () -> Void
    let afRequest: AFRequest?

    public fileprivate(set) var isCancelled = false

    fileprivate var lock: DispatchSemaphore = DispatchSemaphore(value: 1)

    public func cancel() {
        _ = lock.wait(timeout: DispatchTime.distantFuture)
        defer { lock.signal() }
        guard !isCancelled else { return }
        isCancelled = true
        cancelAction()
    }

    public init(action: @escaping () -> Void) {
        self.cancelAction = action
        self.afRequest = nil
    }

    init(request: AFRequest) {
        self.afRequest = request
        self.cancelAction = {
            request.cancel()
        }
    }

    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        guard let request = self.afRequest else {
            return "Empty Request"
        }
        return request.cURLDescription()
    }
}

// MARK: - IrisRequestInterceptor

/// Internal interceptor that bridges Plugin system to Alamofire
final class IrisRequestInterceptor: Alamofire.RequestInterceptor {
    var prepare: ((URLRequest) -> URLRequest)?
    var willSend: ((URLRequest) -> Void)?

    init(prepare: ((URLRequest) -> URLRequest)? = nil, willSend: ((URLRequest) -> Void)? = nil) {
        self.prepare = prepare
        self.willSend = willSend
    }

    func adapt(_ urlRequest: URLRequest, for session: Alamofire.Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let request = prepare?(urlRequest) ?? urlRequest
        willSend?(request)
        completion(.success(request))
    }
}
