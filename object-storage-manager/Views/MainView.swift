//
//  MainView.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageSource.createdAt, order: .reverse) private var sources: [StorageSource]
    
    @StateObject private var storageManager = StorageManager()
    
    @State private var selectedSource: StorageSource?
    @State private var searchText = ""
    @State private var selectedFile: MediaFile?
    @State private var showingUploadConfirmation = false
    @State private var destinationPath = ""
    @State private var pendingUploadURLs: [URL] = []
    @State private var viewMode: ViewMode = .grid
    @State private var filterType: FilterType = .all
    @State private var selectedSourceTag: String?
    @State private var isDragOver = false
    
    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        
        var iconName: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case images = "Images"
        case videos = "Videos"
        case audio = "Audio"
        case other = "Other"
    }
    
    private var filteredSources: [StorageSource] {
        if let tag = selectedSourceTag {
            return sources.filter { source in
                source.tags.contains { $0.name.caseInsensitiveCompare(tag) == .orderedSame }
            }
        }
        return sources
    }
    
    private var allSourceTags: [String] {
        var tagSet = Set<String>()
        for source in sources {
            source.tags.forEach { tagSet.insert($0.name) }
        }
        return Array(tagSet).sorted()
    }
    
    private var filteredItems: [FileSystemItem] {
        var items = storageManager.items
        
        // Apply filter (only to files, not folders)
        items = items.filter { item in
            switch item {
            case .folder:
                return true  // Always show folders
            case .file(let file):
                switch filterType {
                case .all:
                    return true
                case .images:
                    return file.isImage
                case .videos:
                    return file.isVideo
                case .audio:
                    return file.isAudio
                case .other:
                    return !file.isMedia
                }
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return items
    }
    
    private var breadcrumbItems: [String] {
        if storageManager.currentPath.isEmpty {
            return []
        }
        let components = storageManager.currentPath.split(separator: "/").map(String.init)
        return components
    }
    
    var body: some View {
        HSplitView {
            // Sidebar - Source List
            VStack(spacing: 0) {
                // Source selector header
                HStack {
                    Text("Sources")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Tag filter for sources
                if !allSourceTags.isEmpty {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                Button(action: { selectedSourceTag = nil }) {
                                    Text("All")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedSourceTag == nil ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedSourceTag == nil ? .white : .primary)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                
                                ForEach(allSourceTags, id: \.self) { tag in
                                    Button(action: { selectedSourceTag = tag }) {
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(selectedSourceTag == tag ? Color.accentColor : Color.gray.opacity(0.2))
                                            .foregroundColor(selectedSourceTag == tag ? .white : .primary)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                    }
                }
                
                if sources.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No sources configured")
                            .foregroundColor(.secondary)
                        Text("Go to Settings to add one")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredSources, selection: $selectedSource) { source in
                        HStack(spacing: 10) {
                            Image(systemName: source.providerType.iconName)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(source.bucket)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if storageManager.currentSource?.id == source.id && storageManager.isConnected {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(source)
                    }
                    .onChange(of: selectedSource) { _, newSource in
                        if let source = newSource {
                            Task {
                                await storageManager.connect(to: source)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
            
            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    // Search field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        TextField("Search files...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .frame(minWidth: 120, idealWidth: 200)
                    
                    // Filter menu button
                    Menu {
                        ForEach(FilterType.allCases, id: \.self) { type in
                            Button(action: { filterType = type }) {
                                HStack {
                                    Text(type.rawValue)
                                    if filterType == type {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .imageScale(.medium)
                            Text(filterType.rawValue)
                                .font(.callout)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .help("Filter files by type")
                    
                    Spacer(minLength: 12)
                    
                    // View mode toggle
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.iconName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    .labelsHidden()
                    .help("Change view mode")
                    
                    // Refresh button
                    Button(action: {
                        Task {
                            await storageManager.loadFiles(prefix: storageManager.currentPath)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!storageManager.isConnected || storageManager.isLoading)
                    .help("Refresh files")
                    
                    // Upload with path button
                    Button(action: {
                        pendingUploadURLs = []
                        destinationPath = storageManager.currentPath
                        showingUploadConfirmation = true
                    }) {
                        Label("Upload with Path", systemImage: "arrow.up.doc.on.clipboard")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!storageManager.isConnected)
                    .help("Upload files to a specific path")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Breadcrumb navigation
                if storageManager.isConnected && !breadcrumbItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            Button(action: {
                                Task {
                                    await storageManager.navigateToFolder("")
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "house.fill")
                                        .font(.caption)
                                    Text("Root")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            ForEach(Array(breadcrumbItems.enumerated()), id: \.offset) { index, component in
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    let path = breadcrumbItems[0...index].joined(separator: "/") + "/"
                                    Task {
                                        await storageManager.navigateToFolder(path)
                                    }
                                }) {
                                    Text(component)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(index == breadcrumbItems.count - 1 ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                }
                
                // Content
                ZStack {
                    // Drag and drop zone overlay
                    if isDragOver && storageManager.isConnected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                            )
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.accentColor)
                                    Text("Drop files to upload")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    Text("Files will be uploaded to: \(storageManager.currentPath.isEmpty ? "root folder" : storageManager.currentPath)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .padding()
                            .transition(.opacity)
                            .zIndex(1000)
                    }
                    
                    if !storageManager.isConnected {
                        // Not connected state
                        VStack(spacing: 16) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("Select a source to connect")
                                .font(.headline)
                            
                            if sources.isEmpty {
                                Text("Add sources in Settings first")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if storageManager.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Loading files...")
                                .foregroundColor(.secondary)
                        }
                    } else if let error = storageManager.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            Text("Error")
                                .font(.headline)
                            
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Retry") {
                                Task {
                                    await storageManager.loadFiles()
                                }
                            }
                        }
                    } else if filteredItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: storageManager.currentPath.isEmpty ? "doc" : "folder")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text(searchText.isEmpty ? "No items found" : "No matching items")
                                .font(.headline)
                            
                            if !searchText.isEmpty {
                                Button("Clear search") {
                                    searchText = ""
                                }
                            } else if !storageManager.currentPath.isEmpty {
                                Text("This folder is empty")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // File list/grid
                        ScrollView {
                            if viewMode == .grid {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200))], spacing: 16) {
                                    ForEach(filteredItems) { item in
                                        switch item {
                                        case .folder(let folder):
                                            FolderGridItemView(folder: folder)
                                                .onTapGesture(count: 2) {
                                                    Task {
                                                        await storageManager.navigateToFolder(folder.path)
                                                    }
                                                }
                                        case .file(let file):
                                            FileGridItemView(file: file, isSelected: selectedFile?.id == file.id)
                                                .onTapGesture {
                                                    selectedFile = file
                                                }
                                                .contextMenu {
                                                    fileContextMenu(for: file)
                                                }
                                        }
                                    }
                                }
                                .padding()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(filteredItems) { item in
                                        switch item {
                                        case .folder(let folder):
                                            FolderListItemView(folder: folder)
                                                .onTapGesture(count: 2) {
                                                    Task {
                                                        await storageManager.navigateToFolder(folder.path)
                                                    }
                                                }
                                            Divider()
                                        case .file(let file):
                                            FileListItemView(file: file, isSelected: selectedFile?.id == file.id)
                                                .onTapGesture {
                                                    selectedFile = file
                                                }
                                                .contextMenu {
                                                    fileContextMenu(for: file)
                                                }
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    guard storageManager.isConnected else { return false }
                    
                    Task { @MainActor in
                        var urls: [URL] = []
                        
                        for provider in providers {
                            if let url = await resolveDroppedURL(from: provider) {
                                _ = url.startAccessingSecurityScopedResource()
                                urls.append(url)
                            }
                        }
                        
                        if !urls.isEmpty {
                            pendingUploadURLs = urls
                            destinationPath = storageManager.currentPath
                            showingUploadConfirmation = true
                        }
                    }
                    
                    return true
                }
                .animation(.easeInOut(duration: 0.2), value: isDragOver)
                
                // Status bar
                HStack(spacing: 8) {
                    if storageManager.isConnected {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 7, height: 7)
                            Text("\(storageManager.currentSource?.name ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: 200)
                    }
                    
                    Spacer(minLength: 8)
                    
                    if storageManager.isUploading {
                        HStack(spacing: 6) {
                            ProgressView(value: storageManager.uploadProgress)
                                .frame(width: 80)
                            Text("Uploading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 12)
                    }
                    
                    Text("\(filteredItems.count) \(filteredItems.count == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .sheet(isPresented: $showingUploadConfirmation) {
            UploadConfirmationSheet(
                files: $pendingUploadURLs,
                destinationPath: $destinationPath,
                storageManager: storageManager,
                onUpload: {
                    Task {
                        await storageManager.uploadFiles(urls: pendingUploadURLs, destinationPath: destinationPath)
                        
                        // Clean up security-scoped resources
                        for url in pendingUploadURLs {
                            url.stopAccessingSecurityScopedResource()
                        }
                        pendingUploadURLs = []
                    }
                    showingUploadConfirmation = false
                },
                onCancel: {
                    // Clean up security-scoped resources
                    for url in pendingUploadURLs {
                        url.stopAccessingSecurityScopedResource()
                    }
                    pendingUploadURLs = []
                    showingUploadConfirmation = false
                }
            )
        }
    }
    
    @ViewBuilder
    private func fileContextMenu(for file: MediaFile) -> some View {
        if let url = file.url {
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
            
            Button("Open in Browser") {
                NSWorkspace.shared.open(url)
            }
            
            Divider()
        }
        
        Button("Delete", role: .destructive) {
            Task {
                await storageManager.deleteFile(file)
            }
        }
    }
    
}

// MARK: - Upload Confirmation Sheet
struct UploadConfirmationSheet: View {
    @Binding var files: [URL]
    @Binding var destinationPath: String
    @ObservedObject var storageManager: StorageManager
    let onUpload: () -> Void
    let onCancel: () -> Void
    
    @State private var isDragOver = false
    @State private var isEditingPath = false
    @State private var showingFileImporter = false
    
    private var totalSize: Int64 {
        files.reduce(0) { total, url in
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                return total + fileSize
            }
            return total
        }
    }
    
    private var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private var fileTypeBreakdown: [(String, Int)] {
        let grouped = Dictionary(grouping: files) { url -> String in
            let ext = url.pathExtension.lowercased()
            if ext.isEmpty { return "Other" }
            
            let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "svg"]
            let videoExts = ["mp4", "mov", "avi", "mkv", "webm", "m4v"]
            let audioExts = ["mp3", "wav", "aac", "m4a", "flac", "ogg"]
            let docExts = ["pdf", "doc", "docx", "txt", "rtf"]
            
            if imageExts.contains(ext) { return "Images" }
            if videoExts.contains(ext) { return "Videos" }
            if audioExts.contains(ext) { return "Audio" }
            if docExts.contains(ext) { return "Documents" }
            return "Other"
        }
        
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }
    
    private var displayPath: String {
        destinationPath.isEmpty ? "/" : "/" + destinationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upload Confirmation")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Review and confirm files before uploading")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Destination Path Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Upload Destination")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { isEditingPath.toggle() }) {
                            Label(isEditingPath ? "Done" : "Edit Path", systemImage: isEditingPath ? "checkmark" : "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if isEditingPath {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            TextField("path/to/folder", text: $destinationPath)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(displayPath)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal, 24)
            }
            
            Divider()
                .padding(.top, 16)
            
            // Summary Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(files.count)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formattedTotalSize)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Types")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(fileTypeBreakdown.prefix(3), id: \.0) { type, count in
                            Text("\(type): \(count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Divider()
            
            // File List with Drop Zone
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(files.enumerated()), id: \.offset) { index, url in
                            FileUploadRow(
                                url: url,
                                onDelete: {
                                    url.stopAccessingSecurityScopedResource()
                                    files.remove(at: index)
                                }
                            )
                            
                            if index < files.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                        
                        // Add files prompt - enhanced for empty state
                        if !isDragOver {
                            VStack(spacing: 16) {
                                if files.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "arrow.up.doc.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.accentColor)

                                        Text("No files selected yet")
                                            .font(.headline)
                                            .fontWeight(.medium)

                                        Text("Drag and drop files here or use the file browser to add files to upload")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)

                                        Button("Browse Files") {
                                            showingFileImporter = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 60)
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary)

                                        Text("Drag more files here to add them")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Drop overlay
                if isDragOver {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.accentColor)
                                Text("Drop to add more files")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        )
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                Task { @MainActor in
                    var newURLs: [URL] = []
                    
                    for provider in providers {
                        if let url = await resolveDroppedURL(from: provider) {
                            _ = url.startAccessingSecurityScopedResource()
                            newURLs.append(url)
                        }
                    }
                    
                    files.append(contentsOf: newURLs)
                }
                
                return true
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: onUpload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upload \(files.count) \(files.count == 1 ? "File" : "Files")")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(files.isEmpty)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 600)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let validURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
                files.append(contentsOf: validURLs)
            case .failure:
                break
            }
        }
    }
}

// MARK: - File Upload Row
struct FileUploadRow: View {
    let url: URL
    let onDelete: () -> Void
    
    private var fileSize: String {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        return "Unknown"
    }
    
    private var fileIcon: String {
        let ext = url.pathExtension.lowercased()
        
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "svg"]
        let videoExts = ["mp4", "mov", "avi", "mkv", "webm", "m4v"]
        let audioExts = ["mp3", "wav", "aac", "m4a", "flac", "ogg"]
        let docExts = ["pdf", "doc", "docx", "txt", "rtf"]
        
        if imageExts.contains(ext) { return "photo" }
        if videoExts.contains(ext) { return "video" }
        if audioExts.contains(ext) { return "music.note" }
        if docExts.contains(ext) { return "doc" }
        return "doc.fill"
    }
    
    private var fileType: String {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "File" : ext.uppercased()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(fileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(fileType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove file")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Upload Path Dialog
struct UploadPathDialog: View {
    let fileCount: Int
    @Binding var destinationPath: String
    let onUpload: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.doc.on.clipboard")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Upload with Path")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Uploading \(fileCount) \(fileCount == 1 ? "file" : "files")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Path input section
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination Path (Optional)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Specify a folder path in your bucket. Leave empty to upload to the root.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                TextField("e.g., images/2024 or documents/reports", text: $destinationPath)
                    .textFieldStyle(.roundedBorder)
                
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Slashes will create nested folders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Example preview
            if !destinationPath.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text("\(destinationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/filename.ext")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.primary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Upload") {
                    onUpload()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 450)
    }
}

struct FileGridItemView: View {
    let file: MediaFile
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .aspectRatio(1.2, contentMode: .fit)
                
                if file.isImage, file.canPreview, let url = file.url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Image(systemName: file.iconName)
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        @unknown default:
                            Image(systemName: file.iconName)
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if file.isImage && !file.canPreview {
                    VStack(spacing: 8) {
                        Image(systemName: file.iconName)
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Too large")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: file.iconName)
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 3) {
                Text(file.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Text(file.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct FileListItemView: View {
    let file: MediaFile
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.iconName)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(file.key)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 12)
            
            HStack(spacing: 16) {
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
                
                Text(file.lastModified, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct FolderGridItemView: View {
    let folder: FolderItem
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .aspectRatio(1.2, contentMode: .fit)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 3) {
                Text(folder.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                HStack(spacing: 4) {
                    Text("\(folder.fileCount) \(folder.fileCount == 1 ? "item" : "items")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(folder.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct FolderListItemView: View {
    let folder: FolderItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text("\(folder.fileCount) \(folder.fileCount == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 12)
            
            HStack(spacing: 16) {
                Text(folder.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
                
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.clear)
    }
}

#Preview {
    MainView()
}

// MARK: - Helpers
/// Resolve an `NSItemProvider` from Finder drag/drop into a usable file URL.
fileprivate func resolveDroppedURL(from provider: NSItemProvider) async -> URL? {
    // METHOD 1: Load item and convert data representation to URL
    // CRITICAL: When using UTType.fileURL, loadItem returns DATA REPRESENTATION of URL, not the URL itself!
    // This gives us the actual original file URL with proper security-scoped access
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        do {
            let data = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            
            // The data is actually Data type containing the URL representation
            if let urlData = data as? Data,
               let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                return url
            }
            
            // Fallback: try direct URL cast (for other content types)
            if let url = data as? URL {
                return url
            }
        } catch {
            // Silent fail, try next method
        }
    }
    
    // METHOD 2: Copy file representation (this creates a stable copy we can access later)
    // Use this if data representation method fails
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        if let copied = await copyFileRepresentation(from: provider, suggestedName: provider.suggestedName) {
            return copied
        }
    }
    
    // METHOD 3: Try in-place access (NOTE: This gives temporary URLs that may not persist!)
    // Only use as last resort
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        if let url = await withCheckedContinuation({ continuation in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, _, error in
                continuation.resume(returning: url)
            }
        }) {
            return url
        }
    }
    
    return nil
}

// Copy the provider’s file representation to a stable temp file we control.
fileprivate func copyFileRepresentation(from provider: NSItemProvider, suggestedName: String?) async -> URL? {
    await withCheckedContinuation { continuation in
        provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
            if let error {
                print("❌ loadFileRepresentation error: \(error.localizedDescription)")
                continuation.resume(returning: nil)
                return
            }
            
            guard let sourceURL = url else {
                print("❌ No source URL from loadFileRepresentation")
                continuation.resume(returning: nil)
                return
            }
            
            // Get source file size for verification
            let sourceSize = fileSize(at: sourceURL)
            print("Source file: \(sourceURL.path) size=\(sourceSize ?? -1) bytes")
            
            let name = suggestedName ?? sourceURL.lastPathComponent
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_" + name)
            
            do {
                // Copy the file to a stable temp location
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                
                // Verify the copy
                if let destSize = fileSize(at: destination) {
                    if let srcSize = sourceSize, destSize != srcSize {
                        print("⚠️ Warning: Copied file size (\(destSize)) differs from source (\(srcSize))")
                    }
                    print("✓ Copied file representation to temp: \(destination.path) size=\(destSize) bytes")
                } else {
                    print("⚠️ Copied file but size unknown: \(destination.path)")
                }
                continuation.resume(returning: destination)
            } catch {
                print("❌ Failed to copy file representation: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
}

fileprivate func fileSize(at url: URL) -> Int64? {
    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? NSNumber {
        return size.int64Value
    }
    return nil
}
