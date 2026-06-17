// MuseApp.swift — App entry point

import SwiftData
import SwiftUI

@main
struct MuseAppMain: App {
    @StateObject private var engine = MuseEngine()
    let container: ModelContainer = {
        let schema = Schema([StoredChatSession.self, Memory.self, MemoryCluster.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema changed — wipe and recreate so the app doesn't get stuck
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }()

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
            TabView {
                IdeateView()
                    .tabItem {
                        Label("Ideate", systemImage: "sparkles")
                    }

                MemoriesView()
                    .tabItem {
                        Label("Memory", systemImage: "brain")
                    }

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
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
