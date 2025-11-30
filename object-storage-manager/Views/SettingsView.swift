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
    @Query(sort: \StorageAccount.createdAt, order: .reverse) private var accounts: [StorageAccount]
    
    @State private var showingAddAccount = false
    @State private var selectedAccount: StorageAccount?
    @State private var showingDeleteConfirmation = false
    @State private var accountToDelete: StorageAccount?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Storage Buckets")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingAddAccount = true }) {
                    Label("Add Bucket", systemImage: "plus")
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
            
            // Bucket List
            if accounts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Storage Buckets")
                        .font(.headline)
                    
                    Text("Add a storage bucket to get started")
                        .foregroundColor(.secondary)
                    
                    Button("Add Bucket") {
                        showingAddAccount = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(accounts) { account in
                        AccountRowView(account: account)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAccount = account
                            }
                            .contextMenu {
                                Button("Edit") {
                                    selectedAccount = account
                                }
                                
                                Divider()
                                
                                Button("Delete", role: .destructive) {
                                    accountToDelete = account
                                    showingDeleteConfirmation = true
                                }
                            }
                    }
                    .onDelete(perform: deleteAccounts)
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AccountFormView(mode: .add)
        }
        .sheet(item: $selectedAccount) { account in
            AccountFormView(mode: .edit(account))
        }
        .alert("Delete Bucket", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    deleteAccount(account)
                }
            }
        } message: {
            Text("Are you sure you want to delete this bucket? This action cannot be undone.")
        }
    }
    
    private func deleteAccounts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(accounts[index])
            }
        }
    }
    
    private func deleteAccount(_ account: StorageAccount) {
        withAnimation {
            modelContext.delete(account)
        }
    }
}

struct AccountRowView: View {
    let account: StorageAccount
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.providerType.iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                
                Text(account.providerType.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(account.endpoint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.bucket)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                
                if !account.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(account.tags.prefix(3), id: \.self) { tag in
                            TagChip(tag: tag, showDelete: false)
                        }
                        if account.tags.count > 3 {
                            Text("+\(account.tags.count - 3)")
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

enum AccountFormMode: Identifiable {
    case add
    case edit(StorageAccount)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let account): return account.id.uuidString
        }
    }
}

struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let mode: AccountFormMode
    
    @State private var name: String = ""
    @State private var providerType: StorageProviderType = .s3
    @State private var endpoint: String = ""
    @State private var accessKey: String = ""
    @State private var secretKey: String = ""
    @State private var bucket: String = ""
    @State private var region: String = ""
    @State private var useSSL: Bool = true
    @State private var tags: [String] = []
    
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
    
    private var existingAccount: StorageAccount? {
        if case .edit(let account) = mode { return account }
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
                
                Text(isEditing ? "Edit Bucket" : "Add Bucket")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    saveAccount()
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
                Section("Bucket Info") {
                    TextField("Bucket Name", text: $name)
                    
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
                }
                
                Section("Credentials") {
                    TextField("Access Key", text: $accessKey)
                    
                    SecureField("Secret Key", text: $secretKey)
                    
                    TextField("Bucket", text: $bucket)
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
            if let account = existingAccount {
                name = account.name
                providerType = account.providerType
                endpoint = account.endpoint
                accessKey = account.accessKey
                secretKey = account.secretKey
                bucket = account.bucket
                region = account.region
                useSSL = account.useSSL
                tags = account.tags
            } else {
                endpoint = providerType.defaultEndpoint
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        let testAccount = StorageAccount(
            name: name,
            providerType: providerType,
            endpoint: endpoint,
            accessKey: accessKey,
            secretKey: secretKey,
            bucket: bucket,
            region: region,
            useSSL: useSSL
        )
        
        let client = S3Client(account: testAccount)
        
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
    
    private func saveAccount() {
        // Normalize endpoint format for the selected provider
        let normalizedEndpoint = providerType.normalizeEndpoint(endpoint)
        
        if let account = existingAccount {
            account.name = name
            account.providerType = providerType
            account.endpoint = normalizedEndpoint
            account.accessKey = accessKey
            account.secretKey = secretKey
            account.bucket = bucket
            account.region = region
            account.useSSL = useSSL
            account.tags = tags
        } else {
            let newAccount = StorageAccount(
                name: name,
                providerType: providerType,
                endpoint: normalizedEndpoint,
                accessKey: accessKey,
                secretKey: secretKey,
                bucket: bucket,
                region: region,
                useSSL: useSSL,
                tags: tags
            )
            modelContext.insert(newAccount)
        }
    }
}

#Preview {
    SettingsView()
}
