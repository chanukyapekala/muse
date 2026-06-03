// SettingsView.swift — API key management (BYOK)

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: MuseEngine
    @State private var anthropicKey = ""
    @State private var openaiKey = ""
    @State private var openrouterKey = ""
    @State private var saved = false

    private let keychain = KeychainManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your API keys are stored in the iOS Keychain. They never leave your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Anthropic (Claude)") {
                    SecureField("sk-ant-...", text: $anthropicKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    keyStatus(key: "anthropic_api_key")
                }

                Section("OpenAI (GPT)") {
                    SecureField("sk-...", text: $openaiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    keyStatus(key: "openai_api_key")
                }

                Section("OpenRouter") {
                    SecureField("sk-or-...", text: $openrouterKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    keyStatus(key: "openrouter_api_key")
                }

                Section {
                    Button("Save Keys") {
                        saveKeys()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(anthropicKey.isEmpty && openaiKey.isEmpty && openrouterKey.isEmpty)

                    if saved {
                        Label("Keys saved securely", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Models available", value: "\(engine.availableProviders.count)")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func keyStatus(key: String) -> some View {
        HStack {
            if keychain.exists(key: key) {
                Label("Configured", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Button("Remove", role: .destructive) {
                    keychain.delete(key: key)
                    engine.reloadProviders()
                }
                .font(.caption)
            } else {
                Label("Not set", systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveKeys() {
        if !anthropicKey.isEmpty {
            keychain.save(key: "anthropic_api_key", value: anthropicKey)
            anthropicKey = ""
        }
        if !openaiKey.isEmpty {
            keychain.save(key: "openai_api_key", value: openaiKey)
            openaiKey = ""
        }
        if !openrouterKey.isEmpty {
            keychain.save(key: "openrouter_api_key", value: openrouterKey)
            openrouterKey = ""
        }
        engine.reloadProviders()
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
    }
}
