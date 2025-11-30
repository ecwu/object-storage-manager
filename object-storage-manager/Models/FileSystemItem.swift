//
//  FileSystemItem.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/30.
//

import Foundation

enum FileSystemItem: Identifiable, Hashable {
    case folder(FolderItem)
    case file(MediaFile)
    
    var id: String {
        switch self {
        case .folder(let folder):
            return "folder:\(folder.path)"
        case .file(let file):
            return "file:\(file.id)"
        }
    }
    
    var name: String {
        switch self {
        case .folder(let folder):
            return folder.name
        case .file(let file):
            return file.name
        }
    }
    
    var isFolder: Bool {
        if case .folder = self {
            return true
        }
        return false
    }
    
    var file: MediaFile? {
        if case .file(let file) = self {
            return file
        }
        return nil
    }
    
    var folder: FolderItem? {
        if case .folder(let folder) = self {
            return folder
        }
        return nil
    }
}

struct FolderItem: Hashable {
    let name: String
    let path: String  // Full path including the folder name
    let fileCount: Int
    let totalSize: Int64
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}
