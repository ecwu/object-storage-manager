//
//  object_storage_managerApp.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import Foundation
import SwiftUI
import SwiftData

@main
struct object_storage_managerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StorageSource.self,
            Tag.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete the old store and create a new one
            print("Failed to create ModelContainer, attempting to reset: \(error)")
            
            // Get the store URL and delete it
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            
            // Try again with fresh store
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
