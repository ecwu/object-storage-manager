//
//  StorageManager.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import Foundation
import SwiftUI
import Combine

class StorageManager: ObservableObject {
    @Published var files: [MediaFile] = []
    @Published var items: [FileSystemItem] = []
    @Published var currentPath: String = ""
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var currentSource: StorageSource?
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false
    
    private var client: S3Client?
    private let credentialsStore = CredentialsStore()
    
    @MainActor
    func connect(to source: StorageSource) async {
        do {
            let credentials = try credentialsStore.load(for: source.credentialsRef)
            self.currentSource = source
            self.client = S3Client(source: source, credentials: credentials)
        } catch {
            self.errorMessage = "Missing credentials for this source. Please edit and save again."
            self.isConnected = false
            return
        }

        self.isLoading = true
        self.errorMessage = nil
        
        do {
            _ = try await client?.testConnection()
            self.isConnected = true
            self.currentSource?.lastUsedAt = Date()
            await loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
            self.isConnected = false
        }
        
        self.isLoading = false
    }
    
    @MainActor
    func disconnect() {
        self.client = nil
        self.currentSource = nil
        self.isConnected = false
        self.files = []
        self.items = []
        self.currentPath = ""
        self.errorMessage = nil
    }
    
    @MainActor
    func loadFiles(prefix: String = "") async {
        guard let client = client else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        self.currentPath = prefix
        
        do {
            self.files = try await client.listObjects(prefix: prefix)
            self.items = buildFileSystemItems(from: self.files, currentPath: prefix)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    @MainActor
    func navigateToFolder(_ path: String) async {
        await loadFiles(prefix: path)
    }
    
    func buildFileSystemItems(from files: [MediaFile], currentPath: String) -> [FileSystemItem] {
        var items: [FileSystemItem] = []
        var folderMap: [String: (fileCount: Int, totalSize: Int64)] = [:]
        
        // Normalize current path (ensure it ends with / if not empty)
        let normalizedPath = currentPath.isEmpty ? "" : (currentPath.hasSuffix("/") ? currentPath : currentPath + "/")
        
        for file in files {
            let key = file.key
            
            // Remove the current path prefix
            guard key.hasPrefix(normalizedPath) else { continue }
            let relativePath = String(key.dropFirst(normalizedPath.count))
            
            // Check if this file is in a subdirectory
            if let slashIndex = relativePath.firstIndex(of: "/") {
                // It's in a subfolder
                let folderName = String(relativePath[..<slashIndex])
                // Ensure the folder path includes a trailing slash for proper S3 prefix handling
                let folderPath = normalizedPath + folderName + "/"
                
                if var folderInfo = folderMap[folderPath] {
                    folderInfo.fileCount += 1
                    folderInfo.totalSize += file.size
                    folderMap[folderPath] = folderInfo
                } else {
                    folderMap[folderPath] = (fileCount: 1, totalSize: file.size)
                }
            } else {
                // It's a file in the current directory
                items.append(.file(file))
            }
        }
        
        // Create folder items
        let folderItems = folderMap.map { path, info in
            let name = (path as NSString).lastPathComponent
            return FileSystemItem.folder(FolderItem(
                name: name,
                path: path,
                fileCount: info.fileCount,
                totalSize: info.totalSize
            ))
        }.sorted { (item1: FileSystemItem, item2: FileSystemItem) in
            item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
        
        // Sort file items
        let fileItems = items.sorted { (item1: FileSystemItem, item2: FileSystemItem) in
            item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
        
        // Return folders first, then files
        return folderItems + fileItems
    }
    
    @MainActor
    func uploadFile(url: URL) async {
        await uploadFile(url: url, destinationPath: "")
    }
    
    @MainActor
    func uploadFile(url: URL, destinationPath: String) async {
        guard let client = client else { return }
        
        self.isUploading = true
        self.uploadProgress = 0
        self.errorMessage = nil
        
        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            let contentType = guessContentType(for: filename)
            
            // Construct the full key with optional path
            let key = constructKey(filename: filename, destinationPath: destinationPath)
            
            try await client.uploadObject(key: key, data: data, contentType: contentType)
            
            self.uploadProgress = 1.0
            await loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isUploading = false
    }
    
    @MainActor
    func uploadFiles(urls: [URL], destinationPath: String = "") async {
        guard let client = client else { return }
        
        self.isUploading = true
        self.errorMessage = nil
        
        let totalFiles = urls.count
        var uploadedFiles = 0
        
        for url in urls {
            do {
                // For file-reference URLs, try to resolve to standard file URL
                var fileURL = url
                if url.scheme == "file-reference" {
                    do {
                        let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                        var isStale = false
                        let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                        fileURL = resolvedURL
                    } catch {
                        // Use original URL if resolution fails
                    }
                }
                
                // Check if file exists and is accessible
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    throw NSError(domain: "StorageManager", code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "File does not exist at path: \(fileURL.path)"])
                }
                
                // Check if file is readable
                guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
                    throw NSError(domain: "StorageManager", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "File is not readable at path: \(fileURL.path)"])
                }
                
                // Try to read file data with error handling
                let data: Data
                do {
                    data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                } catch {
                    data = try Data(contentsOf: fileURL, options: .uncached)
                }
                
                guard !data.isEmpty else {
                    throw NSError(domain: "StorageManager", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "File data is empty"])
                }
                
                let filename = fileURL.lastPathComponent
                let contentType = guessContentType(for: filename)
                
                // Construct the full key with optional path
                let key = constructKey(filename: filename, destinationPath: destinationPath)
                
                try await client.uploadObject(key: key, data: data, contentType: contentType)
                
                uploadedFiles += 1
                self.uploadProgress = Double(uploadedFiles) / Double(totalFiles)
            } catch {
                self.errorMessage = "Failed to upload \(url.lastPathComponent): \(error.localizedDescription)"
                // Continue with other files even if one fails
            }
        }
        
        self.uploadProgress = 1.0
        await loadFiles()
        self.isUploading = false
    }
    
    @MainActor
    func uploadData(_ data: Data, filename: String) async {
        await uploadData(data, filename: filename, destinationPath: "")
    }
    
    @MainActor
    func uploadData(_ data: Data, filename: String, destinationPath: String) async {
        guard let client = client else { return }
        
        self.isUploading = true
        self.uploadProgress = 0
        self.errorMessage = nil
        
        do {
            let contentType = guessContentType(for: filename)
            
            // Construct the full key with optional path
            let key = constructKey(filename: filename, destinationPath: destinationPath)
            
            try await client.uploadObject(key: key, data: data, contentType: contentType)
            
            self.uploadProgress = 1.0
            await loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isUploading = false
    }
    
    @MainActor
    func deleteFile(_ file: MediaFile) async {
        guard let client = client else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            try await client.deleteObject(key: file.key)
            await loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
    
    // Helper method to construct the storage key with path
    private func constructKey(filename: String, destinationPath: String) -> String {
        let trimmedPath = destinationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if trimmedPath.isEmpty {
            return filename
        } else {
            return "\(trimmedPath)/\(filename)"
        }
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
}
