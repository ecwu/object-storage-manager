//
//  MediaFile.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import Foundation

struct MediaFile: Identifiable, Hashable {
    let id: String
    let name: String
    let key: String
    let size: Int64
    let lastModified: Date
    let contentType: String
    let url: URL?
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var isImage: Bool {
        contentType.hasPrefix("image/") || 
        ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic"].contains(fileExtension.lowercased())
    }
    
    var isVideo: Bool {
        contentType.hasPrefix("video/") ||
        ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"].contains(fileExtension.lowercased())
    }
    
    var isAudio: Bool {
        contentType.hasPrefix("audio/") ||
        ["mp3", "wav", "aac", "flac", "ogg", "m4a"].contains(fileExtension.lowercased())
    }
    
    var isMedia: Bool {
        isImage || isVideo || isAudio
    }
    
    var fileExtension: String {
        (name as NSString).pathExtension
    }
    
    var iconName: String {
        if isImage { return "photo" }
        if isVideo { return "video" }
        if isAudio { return "music.note" }
        return "doc"
    }
}
