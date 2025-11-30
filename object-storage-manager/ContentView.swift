//
//  ContentView.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/28.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingSettings = false
    
    var body: some View {
        MainView()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .frame(minWidth: 700, minHeight: 500)
            }
            .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: StorageAccount.self, inMemory: true)
}
