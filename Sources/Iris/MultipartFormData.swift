//
//  MultipartFormData.swift
//  Iris
//

import Foundation

/// Multipart 表单数据部分
public struct MultipartFormBodyPart {
    /// 数据提供方式
    public enum Provider {
        case data(Data)
        case file(URL)
        case stream(InputStream, length: UInt64)
    }
    
    public let provider: Provider
    public let name: String
    public let fileName: String?
    public let mimeType: String?
    
    public init(
        provider: Provider,
        name: String,
        fileName: String? = nil,
        mimeType: String? = nil
    ) {
        self.provider = provider
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

// MARK: - Convenience Initializers

public extension MultipartFormBodyPart {
    /// 从 Data 创建
    static func data(
        _ data: Data,
        name: String,
        fileName: String? = nil,
        mimeType: String? = nil
    ) -> MultipartFormBodyPart {
        MultipartFormBodyPart(
            provider: .data(data),
            name: name,
            fileName: fileName,
            mimeType: mimeType
        )
    }
    
    /// 从文件 URL 创建
    static func file(
        _ url: URL,
        name: String,
        fileName: String? = nil,
        mimeType: String? = nil
    ) -> MultipartFormBodyPart {
        MultipartFormBodyPart(
            provider: .file(url),
            name: name,
            fileName: fileName ?? url.lastPathComponent,
            mimeType: mimeType ?? url.mimeType
        )
    }
    
    /// 从 InputStream 创建
    static func stream(
        _ stream: InputStream,
        length: UInt64,
        name: String,
        fileName: String,
        mimeType: String? = nil
    ) -> MultipartFormBodyPart {
        MultipartFormBodyPart(
            provider: .stream(stream, length: length),
            name: name,
            fileName: fileName,
            mimeType: mimeType
        )
    }
    
    /// 从字符串创建表单字段
    static func text(_ value: String, name: String) -> MultipartFormBodyPart {
        MultipartFormBodyPart(
            provider: .data(value.data(using: .utf8) ?? Data()),
            name: name,
            fileName: nil,
            mimeType: nil
        )
    }
}

// MARK: - MIME Type Detection

private extension URL {
    var mimeType: String {
        let pathExtension = self.pathExtension.lowercased()
        
        let mimeTypes: [String: String] = [
            // Images
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "webp": "image/webp",
            "svg": "image/svg+xml",
            "ico": "image/x-icon",
            "bmp": "image/bmp",
            "tiff": "image/tiff",
            "tif": "image/tiff",
            "heic": "image/heic",
            "heif": "image/heif",
            
            // Videos
            "mp4": "video/mp4",
            "mov": "video/quicktime",
            "avi": "video/x-msvideo",
            "wmv": "video/x-ms-wmv",
            "flv": "video/x-flv",
            "webm": "video/webm",
            "mkv": "video/x-matroska",
            
            // Audio
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "aac": "audio/aac",
            "ogg": "audio/ogg",
            "flac": "audio/flac",
            "m4a": "audio/mp4",
            
            // Documents
            "pdf": "application/pdf",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt": "application/vnd.ms-powerpoint",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            
            // Text
            "txt": "text/plain",
            "html": "text/html",
            "htm": "text/html",
            "css": "text/css",
            "js": "application/javascript",
            "json": "application/json",
            "xml": "application/xml",
            "csv": "text/csv",
            
            // Archives
            "zip": "application/zip",
            "rar": "application/x-rar-compressed",
            "7z": "application/x-7z-compressed",
            "tar": "application/x-tar",
            "gz": "application/gzip",
            
            // Others
            "bin": "application/octet-stream"
        ]
        
        return mimeTypes[pathExtension] ?? "application/octet-stream"
    }
}
