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
    @Published var currentAccount: StorageAccount?
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false
    
    private var client: S3Client?
    
    @MainActor
    func connect(to account: StorageAccount) async {
        self.currentAccount = account
        self.client = S3Client(account: account)
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            _ = try await client?.testConnection()
            self.isConnected = true
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
        self.currentAccount = nil
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
        guard let client = client else { return }
        
        self.isUploading = true
        self.uploadProgress = 0
        self.errorMessage = nil
        
        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            let contentType = guessContentType(for: filename)
            
            try await client.uploadObject(key: filename, data: data, contentType: contentType)
            
            self.uploadProgress = 1.0
            await loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isUploading = false
    }
    
    @MainActor
    func uploadData(_ data: Data, filename: String) async {
        guard let client = client else { return }
        
        self.isUploading = true
        self.uploadProgress = 0
        self.errorMessage = nil
        
        do {
            let contentType = guessContentType(for: filename)
            try await client.uploadObject(key: filename, data: data, contentType: contentType)
            
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
