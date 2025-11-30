//
//  SettingsView.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageSource.createdAt, order: .reverse) private var sources: [StorageSource]
    
    @State private var showingAddSource = false
    @State private var selectedSource: StorageSource?
    @State private var showingDeleteConfirmation = false
    @State private var sourceToDelete: StorageSource?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Storage Sources")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingAddSource = true }) {
                    Label("Add Source", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Source List
            if sources.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Storage Sources")
                        .font(.headline)
                    
                    Text("Add a storage bucket to get started")
                        .foregroundColor(.secondary)
                    
                    Button("Add Source") {
                        showingAddSource = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sources) { source in
                        SourceRowView(source: source)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSource = source
                            }
                            .contextMenu {
                                Button("Edit") {
                                    selectedSource = source
                                }
                                
                                Divider()
                                
                                Button("Delete", role: .destructive) {
                                    sourceToDelete = source
                                    showingDeleteConfirmation = true
                                }
                            }
                    }
                    .onDelete(perform: deleteSources)
                }
            }
        }
        .sheet(isPresented: $showingAddSource) {
            SourceFormView(mode: .add)
        }
        .sheet(item: $selectedSource) { source in
            SourceFormView(mode: .edit(source))
        }
        .alert("Delete Source", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let source = sourceToDelete {
                    deleteSource(source)
                }
            }
        } message: {
            Text("Are you sure you want to delete this source? This action cannot be undone.")
        }
    }
    
    private func deleteSources(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let source = sources[index]
                CredentialsStore().delete(for: source.credentialsRef)
                modelContext.delete(source)
            }
        }
    }
    
    private func deleteSource(_ source: StorageSource) {
        withAnimation {
            CredentialsStore().delete(for: source.credentialsRef)
            modelContext.delete(source)
        }
    }
}

struct SourceRowView: View {
    let source: StorageSource
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.providerType.iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.headline)
                
                Text(source.providerType.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(source.endpoint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(source.bucket)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                
                if !source.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(source.tags.prefix(3)) { tag in
                            TagChip(tag: tag.name, showDelete: false)
                        }
                        if source.tags.count > 3 {
                            Text("+\(source.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

enum SourceFormMode: Identifiable {
    case add
    case edit(StorageSource)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let source): return source.id.uuidString
        }
    }
}

struct SourceFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let mode: SourceFormMode
    private let credentialsStore = CredentialsStore()
    
    @State private var name: String = ""
    @State private var providerType: StorageProviderType = .s3
    @State private var endpoint: String = ""
    @State private var accessKey: String = ""
    @State private var secretKey: String = ""
    @State private var bucket: String = ""
    @State private var region: String = ""
    @State private var useSSL: Bool = true
    @State private var tags: [String] = []
    @State private var pathStyleEnabled: Bool = false
    @State private var note: String = ""
    
    @State private var isTesting = false
    @State private var testResult: TestResult?
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var existingSource: StorageSource? {
        if case .edit(let source) = mode { return source }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text(isEditing ? "Edit Source" : "Add Source")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    saveSource()
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || endpoint.isEmpty || accessKey.isEmpty || secretKey.isEmpty || bucket.isEmpty)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section("Source Info") {
                    TextField("Source Name", text: $name)
                    TextField("Bucket", text: $bucket)
                    
                    Picker("Provider", selection: $providerType) {
                        ForEach(StorageProviderType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .onChange(of: providerType) { _, newValue in
                        if endpoint.isEmpty || StorageProviderType.allCases.map({ $0.defaultEndpoint }).contains(endpoint) {
                            endpoint = newValue.defaultEndpoint
                        }
                    }
                }
                
                Section("Connection") {
                    TextField("Endpoint", text: $endpoint)
                        .textContentType(.URL)
                    
                    TextField("Region (optional)", text: $region)
                    
                    Toggle("Use SSL (HTTPS)", isOn: $useSSL)
                    Toggle("Path-style requests", isOn: $pathStyleEnabled)
                    
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
                
                Section("Credentials") {
                    TextField("Access Key", text: $accessKey)
                    
                    SecureField("Secret Key", text: $secretKey)
                }
                
                Section("Tags") {
                    TagManagementView(
                        tags: $tags,
                        suggestedTags: ["Production", "Development", "Testing", "Archive", "Backup", "Media"]
                    )
                }
                
                Section {
                    HStack {
                        Button(action: testConnection) {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                                Text("Testing...")
                            } else {
                                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(endpoint.isEmpty || accessKey.isEmpty || secretKey.isEmpty || bucket.isEmpty || isTesting)
                        
                        if let testResult = testResult {
                            Spacer()
                            switch testResult {
                            case .success:
                                Label("Connection successful", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            case .failure(let error):
                                Label(error, systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 550)
        .onAppear {
            if let source = existingSource {
                name = source.name
                providerType = source.providerType
                endpoint = source.endpoint
                bucket = source.bucket
                region = source.region
                useSSL = source.useSSL
                pathStyleEnabled = source.pathStyleEnabled
                note = source.note ?? ""
                tags = source.tags.map { $0.name }
                
                if let creds = try? credentialsStore.load(for: source.credentialsRef) {
                    accessKey = creds.accessKey
                    secretKey = creds.secretKey
                }
            } else {
                endpoint = providerType.defaultEndpoint
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        let source = StorageSource(
            name: name,
            providerType: providerType,
            endpoint: endpoint,
            bucket: bucket,
            region: region,
            useSSL: useSSL,
            pathStyleEnabled: pathStyleEnabled,
            credentialsRef: UUID().uuidString
        )
        
        let credentials = StorageCredentials(accessKey: accessKey, secretKey: secretKey)
        let client = S3Client(source: source, credentials: credentials)
        
        Task {
            do {
                _ = try await client.testConnection()
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }
    
    private func saveSource() {
        // Normalize endpoint format for the selected provider
        let normalizedEndpoint = providerType.normalizeEndpoint(endpoint)
        let resolvedTags = resolveTags(tags)
        let credentials = StorageCredentials(accessKey: accessKey, secretKey: secretKey)

        if let source = existingSource {
            source.name = name
            source.providerType = providerType
            source.endpoint = normalizedEndpoint
            source.bucket = bucket
            source.region = region
            source.useSSL = useSSL
            source.pathStyleEnabled = pathStyleEnabled
            source.note = note.isEmpty ? nil : note
            source.tags = resolvedTags
            if source.lastUsedAt == nil { source.lastUsedAt = Date() }
            try? credentialsStore.save(credentials: credentials, for: source.credentialsRef)
        } else {
            let newId = UUID()
            let credentialsRef = newId.uuidString
            let newSource = StorageSource(
                id: newId,
                name: name,
                providerType: providerType,
                endpoint: normalizedEndpoint,
                bucket: bucket,
                region: region,
                useSSL: useSSL,
                pathStyleEnabled: pathStyleEnabled,
                note: note.isEmpty ? nil : note,
                createdAt: Date(),
                lastUsedAt: Date(),
                credentialsRef: credentialsRef,
                tags: resolvedTags
            )
            modelContext.insert(newSource)
            try? credentialsStore.save(credentials: credentials, for: credentialsRef)
        }
    }
    
    private func resolveTags(_ names: [String]) -> [Tag] {
        let trimmed = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var results: [Tag] = []
        
        for name in trimmed {
            let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
            if let existing = try? modelContext.fetch(descriptor).first {
                results.append(existing)
            } else {
                let newTag = Tag(name: name)
                modelContext.insert(newTag)
                results.append(newTag)
            }
        }
        return results
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [StorageSource.self, Tag.self], inMemory: true)
}
