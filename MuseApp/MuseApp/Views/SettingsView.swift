// SettingsView.swift — No accounts, no keys. Just a chat-history toggle and About.

import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Runs fully on-device. No accounts, no API keys, no network calls for chat.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Personalization") {
                    let nameField = TextField("Your name", text: $userName)
                        .autocorrectionDisabled()
                    #if os(iOS)
                    nameField.textInputAutocapitalization(.words)
                    #else
                    nameField
                    #endif
                    Text("Used to greet you when you open Muse. Stored only on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Chat history") {
                    Text("Conversations are saved locally on this device. Clear them anytime from the Ideate tab or the History tab.")
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
