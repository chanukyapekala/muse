// MuseApp.swift — App entry point

import SwiftData
import SwiftUI

@main
struct MuseAppMain: App {
    @StateObject private var engine = MuseEngine()
    let container: ModelContainer = {
        let schema = Schema([StoredChatSession.self, Memory.self, MemoryCluster.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            // Schema mismatch — delete all SQLite files and start fresh
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let suffixes = ["", "-wal", "-shm"]
                for suffix in suffixes {
                    let file = appSupport.appendingPathComponent("default.store\(suffix)")
                    try? FileManager.default.removeItem(at: file)
                }
            }
            // Try once more; fall back to in-memory if it still fails
            return (try? ModelContainer(for: schema))
                ?? (try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
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
