// SettingsView.swift — No accounts, no keys. Just a chat-history toggle and About.

import SwiftUI

struct SettingsView: View {
    @AppStorage("saveChatHistory") private var saveChatHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Runs fully on-device. No accounts, no API keys, no network calls for chat.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Chat history") {
                    Toggle("Save chat history on this device", isOn: $saveChatHistory)
                    Text(saveChatHistory
                         ? "Conversations are saved locally on this device only."
                         : "Conversations vanish when you close the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Model", value: "Llama 3.2 1B (on-device)")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
