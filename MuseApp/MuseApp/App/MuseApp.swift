// MuseApp.swift — App entry point

import SwiftData
import SwiftUI

@main
struct MuseAppMain: App {
    @StateObject private var engine = MuseEngine()

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
        .modelContainer(for: StoredChatSession.self)
    }
}
