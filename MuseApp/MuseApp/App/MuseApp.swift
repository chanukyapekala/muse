// MuseApp.swift — App entry point

import SwiftData
import SwiftUI

@main
struct MuseAppMain: App {
    @StateObject private var engine = MuseEngine()
    let container: ModelContainer = Self.makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([StoredChatSession.self, MemoryCluster.self, ClusterEdge.self, ChatThread.self])

        // 1. Try normal persistent store
        if let c = try? ModelContainer(for: schema) { return c }

        // 2. Schema mismatch — wipe all SQLite files and retry
        if let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("default.store\(suffix)"))
            }
        }
        if let c = try? ModelContainer(for: schema) { return c }

        // 3. Last resort: in-memory only (data won't persist but app won't crash)
        let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
        if let c = try? ModelContainer(for: schema, configurations: inMemory) { return c }

        // 4. Should never reach here — empty schema as absolute fallback
        return try! ModelContainer(for: Schema([]))
    }

    init() {
        // Force window background to black so no dead space shows
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.backgroundColor = .black
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $engine.selectedTab) {
                IdeateView()
                    .tabItem {
                        Label("Ideate", systemImage: "sparkles")
                    }
                    .tag(0)

                AuraView()
                    .tabItem {
                        Label("Aura", systemImage: "sparkle")
                    }
                    .tag(1)

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .preferredColorScheme(.dark)
            .onAppear {
                #if os(iOS)
                let scenes = UIApplication.shared.connectedScenes
                for scene in scenes {
                    if let windowScene = scene as? UIWindowScene {
                        for window in windowScene.windows {
                            window.backgroundColor = .black
                        }
                    }
                }
                #endif
            }
            .environmentObject(engine)
        }
        .modelContainer(container)
    }
}
