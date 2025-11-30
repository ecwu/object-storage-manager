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
        self.errorMessage = nil
    }
    
    @MainActor
    func loadFiles(prefix: String = "") async {
        guard let client = client else { return }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            self.files = try await client.listObjects(prefix: prefix)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
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
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
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
    
    // Helper method to construct the storage key with path
    private func constructKey(filename: String, destinationPath: String) -> String {
        let trimmedPath = destinationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if trimmedPath.isEmpty {
            return filename
        } else {
            return "\(trimmedPath)/\(filename)"
        }
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
