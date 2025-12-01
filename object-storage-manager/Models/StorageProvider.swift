//
//  StorageProvider.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import Foundation
import SwiftData

enum StorageProviderType: String, Codable, CaseIterable {
    case s3 = "Amazon S3"
    case minio = "MinIO"
    case qiniu = "Qiniu"
    case aliyun = "Aliyun OSS"
    case tencent = "Tencent COS"
    
    var iconName: String {
        switch self {
        case .s3: return "cloud.fill"
        case .minio: return "server.rack"
        case .qiniu: return "icloud.fill"
        case .aliyun: return "cloud.circle.fill"
        case .tencent: return "cloud.bolt.fill"
        }
    }
    
    var defaultEndpoint: String {
        switch self {
        case .s3: return "s3.amazonaws.com"
        case .minio: return "localhost:9000"
        case .qiniu: return "s3-cn-east-1.qiniucs.com"
        case .aliyun: return "oss-cn-hangzhou.aliyuncs.com"
        case .tencent: return "cos.ap-guangzhou.myqcloud.com"
        }
    }
    
    /// Normalizes the endpoint format for the provider.
    /// For Qiniu: converts "s3.region.qiniucs.com" to "s3-region.qiniucs.com".
    func normalizeEndpoint(_ endpoint: String) -> String {
        switch self {
        case .qiniu:
            if endpoint.hasPrefix("s3.") && endpoint.hasSuffix(".qiniucs.com") {
                return endpoint.replacingOccurrences(of: "s3.", with: "s3-", options: [], range: endpoint.startIndex..<endpoint.index(endpoint.startIndex, offsetBy: 3))
            }
            return endpoint
        default:
            return endpoint
        }
    }
}

@Model
final class Tag {
    var id: UUID
    var name: String
    @Relationship(inverse: \StorageSource.tags) var sources: [StorageSource] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class StorageSource {
    var id: UUID
    var name: String
    var providerTypeRaw: String
    var endpoint: String
    var bucket: String
    var region: String
    var useSSL: Bool
    var pathStyleEnabled: Bool
    var note: String?
    var cdnUrl: String?
    var createdAt: Date
    var lastUsedAt: Date?
    var lastCheck: Date?
    var lastError: String?
    var credentialsRef: String
    
    @Relationship var tags: [Tag] = []
    
    var providerType: StorageProviderType {
        get { StorageProviderType(rawValue: providerTypeRaw) ?? .s3 }
        set { providerTypeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        providerType: StorageProviderType,
        endpoint: String,
        bucket: String,
        region: String = "",
        useSSL: Bool = true,
        pathStyleEnabled: Bool = false,
        note: String? = nil,
        cdnUrl: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        lastCheck: Date? = nil,
        lastError: String? = nil,
        credentialsRef: String,
        tags: [Tag] = []
    ) {
        self.id = id
        self.name = name
        self.providerTypeRaw = providerType.rawValue
        self.endpoint = endpoint
        self.bucket = bucket
        self.region = region
        self.useSSL = useSSL
        self.pathStyleEnabled = pathStyleEnabled
        self.note = note
        self.cdnUrl = cdnUrl
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.lastCheck = lastCheck
        self.lastError = lastError
        self.credentialsRef = credentialsRef
        self.tags = tags
    }
}
