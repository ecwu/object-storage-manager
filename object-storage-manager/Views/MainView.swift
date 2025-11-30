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
    @State private var showingUploadSheet = false
    @State private var showingUploadWithPathSheet = false
    @State private var showingPathDialog = false
    @State private var destinationPath = ""
    @State private var pendingUploadURLs: [URL] = []
    @State private var viewMode: ViewMode = .grid
    @State private var filterType: FilterType = .all
    @State private var selectedSourceTag: String?
    
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
    
    private var filteredFiles: [MediaFile] {
        var files = storageManager.files
        
        // Apply filter
        switch filterType {
        case .all:
            break
        case .images:
            files = files.filter { $0.isImage }
        case .videos:
            files = files.filter { $0.isVideo }
        case .audio:
            files = files.filter { $0.isAudio }
        case .other:
            files = files.filter { !$0.isMedia }
        }
        
        // Apply search
        if !searchText.isEmpty {
            files = files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return files
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
                            await storageManager.loadFiles()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!storageManager.isConnected || storageManager.isLoading)
                    .help("Refresh files")
                    
                    // Upload button with menu
                    Menu {
                        Button(action: { showingUploadSheet = true }) {
                            Label("Simple Upload", systemImage: "arrow.up.doc")
                        }
                        
                        Button(action: { showingUploadWithPathSheet = true }) {
                            Label("Upload with Path", systemImage: "arrow.up.doc.on.clipboard")
                        }
                    } label: {
                        Label("Upload", systemImage: "arrow.up.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.borderedProminent)
                    .disabled(!storageManager.isConnected)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Content
                ZStack {
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
                    } else if filteredFiles.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text(searchText.isEmpty ? "No files found" : "No matching files")
                                .font(.headline)
                            
                            if !searchText.isEmpty {
                                Button("Clear search") {
                                    searchText = ""
                                }
                            }
                        }
                    } else {
                        // File list/grid
                        ScrollView {
                            if viewMode == .grid {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200))], spacing: 16) {
                                    ForEach(filteredFiles) { file in
                                        FileGridItemView(file: file, isSelected: selectedFile?.id == file.id)
                                            .onTapGesture {
                                                selectedFile = file
                                            }
                                            .contextMenu {
                                                fileContextMenu(for: file)
                                            }
                                    }
                                }
                                .padding()
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(filteredFiles) { file in
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
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
                    
                    Text("\(filteredFiles.count) \(filteredFiles.count == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .fileImporter(
            isPresented: $showingUploadSheet,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    // Simple upload - no path
                    var accessedURLs: [URL] = []
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            accessedURLs.append(url)
                        }
                    }
                    
                    await storageManager.uploadFiles(urls: accessedURLs, destinationPath: "")
                    
                    for url in accessedURLs {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                print("File import error: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingUploadWithPathSheet,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                // Store selected files and show path dialog
                pendingUploadURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
                destinationPath = ""
                showingPathDialog = true
            case .failure(let error):
                print("File import error: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showingPathDialog) {
            UploadPathDialog(
                fileCount: pendingUploadURLs.count,
                destinationPath: $destinationPath,
                onUpload: {
                    Task {
                        await storageManager.uploadFiles(urls: pendingUploadURLs, destinationPath: destinationPath)
                        
                        // Clean up security-scoped resources
                        for url in pendingUploadURLs {
                            url.stopAccessingSecurityScopedResource()
                        }
                        pendingUploadURLs = []
                    }
                    showingPathDialog = false
                },
                onCancel: {
                    // Clean up security-scoped resources
                    for url in pendingUploadURLs {
                        url.stopAccessingSecurityScopedResource()
                    }
                    pendingUploadURLs = []
                    showingPathDialog = false
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
                
                if file.isImage, let url = file.url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
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
                    .cornerRadius(8)
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

#Preview {
    MainView()
}
