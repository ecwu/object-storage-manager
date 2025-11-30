//
//  S3Client.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import Foundation
import CryptoKit

class S3Client {
    private let source: StorageSource
    private let credentials: StorageCredentials
    private let session: URLSession
    
    init(source: StorageSource, credentials: StorageCredentials) {
        self.source = source
        self.credentials = credentials
        self.session = URLSession.shared
    }
    
    private var baseURL: String {
        let scheme = source.useSSL ? "https" : "http"
        return "\(scheme)://\(host)"
    }
    
    private var host: String {
        source.pathStyleEnabled ? source.endpoint : "\(source.bucket).\(source.endpoint)"
    }
    
    private var bucketPrefix: String {
        source.pathStyleEnabled ? "/\(source.bucket)" : ""
    }
    
    // MARK: - AWS Signature V4
    
    private func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(signature)
    }
    
    private func sha256Hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func getSignatureKey(dateStamp: String, regionName: String, serviceName: String) -> Data {
        let kDate = hmacSHA256(key: Data("AWS4\(credentials.secretKey)".utf8), data: Data(dateStamp.utf8))
        let kRegion = hmacSHA256(key: kDate, data: Data(regionName.utf8))
        let kService = hmacSHA256(key: kRegion, data: Data(serviceName.utf8))
        let kSigning = hmacSHA256(key: kService, data: Data("aws4_request".utf8))
        return kSigning
    }
    
    // RFC 3986 compliant percent encoding for AWS Signature V4
    private func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
    
    private func signRequest(method: String, uri: String, queryParams: [String: String] = [:], headers: [String: String], payload: Data = Data()) -> [String: String] {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)
        
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)
        
        let region = source.region.isEmpty ? "us-east-1" : source.region
        let service = "s3"
        
        var allHeaders = headers
        allHeaders["x-amz-date"] = amzDate
        allHeaders["x-amz-content-sha256"] = sha256Hash(payload)
        
        let sortedHeaders = allHeaders.sorted { $0.key.lowercased() < $1.key.lowercased() }
        let signedHeaders = sortedHeaders.map { $0.key.lowercased() }.joined(separator: ";")
        let canonicalHeaders = sortedHeaders.map { "\($0.key.lowercased()):\($0.value.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n") + "\n"
        
        let sortedQueryParams = queryParams.sorted { $0.key < $1.key }
        let canonicalQueryString = sortedQueryParams.map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }.joined(separator: "&")
        
        let payloadHash = sha256Hash(payload)
        
        let canonicalRequest = [
            method,
            uri,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
        
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hash(Data(canonicalRequest.utf8))
        ].joined(separator: "\n")
        
        let signingKey = getSignatureKey(dateStamp: dateStamp, regionName: region, serviceName: service)
        let signature = hmacSHA256(key: signingKey, data: Data(stringToSign.utf8))
        let signatureHex = signature.map { String(format: "%02x", $0) }.joined()
        
        let authorization = "AWS4-HMAC-SHA256 Credential=\(credentials.accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signatureHex)"
        
        var resultHeaders = allHeaders
        resultHeaders["Authorization"] = authorization
        
        return resultHeaders
    }
    
    // MARK: - API Methods
    
    func listObjects(prefix: String = "", maxKeys: Int = 1000) async throws -> [MediaFile] {
        let uri = bucketPrefix.isEmpty ? "/" : bucketPrefix
        var queryParams: [String: String] = [
            "list-type": "2",
            "max-keys": "\(maxKeys)"
        ]
        if !prefix.isEmpty {
            queryParams["prefix"] = prefix
        }
        
        let headers: [String: String] = ["Host": host]
        
        let signedHeaders = signRequest(method: "GET", uri: uri, queryParams: queryParams, headers: headers)
        
        // Use the same encoding for the actual query string as we used in the canonical request
        let sortedQueryParams = queryParams.sorted { $0.key < $1.key }
        let queryString = sortedQueryParams.map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }.joined(separator: "&")
        
        guard let url = URL(string: "\(baseURL)\(uri)?\(queryString)") else {
            throw S3Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in signedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3Error.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw S3Error.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        return parseListResponse(data)
    }
    
    private func parseListResponse(_ data: Data) -> [MediaFile] {
        var files: [MediaFile] = []
        
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return files
        }
        
        let contentsPattern = "<Contents>(.*?)</Contents>"
        guard let contentsRegex = try? NSRegularExpression(pattern: contentsPattern, options: .dotMatchesLineSeparators) else {
            return files
        }
        
        let range = NSRange(xmlString.startIndex..., in: xmlString)
        let matches = contentsRegex.matches(in: xmlString, options: [], range: range)
        
        for match in matches {
            if let contentRange = Range(match.range(at: 1), in: xmlString) {
                let content = String(xmlString[contentRange])
                
                let key = extractXMLValue(from: content, tag: "Key") ?? ""
                let sizeStr = extractXMLValue(from: content, tag: "Size") ?? "0"
                let lastModifiedStr = extractXMLValue(from: content, tag: "LastModified") ?? ""
                
                let size = Int64(sizeStr) ?? 0
                let lastModified = parseISO8601Date(lastModifiedStr) ?? Date()
                
                let name = (key as NSString).lastPathComponent
                let contentType = guessContentType(for: name)
                
                let file = MediaFile(
                    id: key,
                    name: name,
                    key: key,
                    size: size,
                    lastModified: lastModified,
                    contentType: contentType,
                    url: getObjectURL(key: key)
                )
                files.append(file)
            }
        }
        
        return files
    }
    
    private func extractXMLValue(from xml: String, tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return nil
        }
        let range = NSRange(xml.startIndex..., in: xml)
        if let match = regex.firstMatch(in: xml, options: [], range: range),
           let valueRange = Range(match.range(at: 1), in: xml) {
            return String(xml[valueRange])
        }
        return nil
    }
    
    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    private func guessContentType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        let mimeTypes: [String: String] = [
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "webp": "image/webp",
            "bmp": "image/bmp",
            "mp4": "video/mp4",
            "mov": "video/quicktime",
            "avi": "video/x-msvideo",
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "pdf": "application/pdf",
            "json": "application/json",
            "txt": "text/plain"
        ]
        return mimeTypes[ext] ?? "application/octet-stream"
    }
    
    func getObjectURL(key: String) -> URL? {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return URL(string: "\(baseURL)\(bucketPrefix)/\(encodedKey)")
    }
    
    func uploadObject(key: String, data: Data, contentType: String) async throws {
        let uri = "\(bucketPrefix)/\(key)"
        
        let headers: [String: String] = [
            "Host": host,
            "Content-Type": contentType,
            "Content-Length": "\(data.count)"
        ]
        
        let signedHeaders = signRequest(method: "PUT", uri: uri, headers: headers, payload: data)
        
        guard let url = URL(string: "\(baseURL)\(uri)") else {
            throw S3Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        for (key, value) in signedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3Error.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw S3Error.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    func deleteObject(key: String) async throws {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        let uri = "\(bucketPrefix)/\(encodedKey)"
        
        let headers: [String: String] = ["Host": host]
        let signedHeaders = signRequest(method: "DELETE", uri: uri, headers: headers)
        
        guard let url = URL(string: "\(baseURL)\(uri)") else {
            throw S3Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        for (key, value) in signedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3Error.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw S3Error.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    func testConnection() async throws -> Bool {
        _ = try await listObjects(maxKeys: 1)
        return true
    }
}

enum S3Error: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        }
    }
}
