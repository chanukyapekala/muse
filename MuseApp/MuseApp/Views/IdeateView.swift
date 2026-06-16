// IdeateView.swift — Chat-style prompt and response interface

import SwiftData
import SwiftUI

struct IdeateView: View {
    @EnvironmentObject var engine: MuseEngine
    @Environment(\.modelContext) private var modelContext
    @AppStorage("saveChatHistory") private var saveChatHistory = false
    @StateObject private var speech = SpeechRecognizer()
    @State private var prompt = ""
    @State private var promptBeforeRecording = ""
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if engine.currentResponse == nil && !engine.isLoading && engine.error == nil {
                            emptyState
                        }

                        if let response = engine.currentResponse {
                            // User message bubble
                            userBubble(response.prompt)

                            // Model response
                            responseSection(response)
                        }

                        if let error = engine.error {
                            errorCard(error)
                        }

                        if engine.isLoading {
                            if engine.currentResponse == nil {
                                // Show the prompt that was just sent
                                userBubble(engine.lastPrompt)
                            }
                            loadingView
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isPromptFocused = false
                }
                .onChange(of: engine.currentResponse?.id) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    if let response = engine.currentResponse, saveChatHistory {
                        modelContext.insert(StoredChatSession(prompt: response.prompt, answer: response.answer))
                    }
                }
                .onChange(of: engine.isLoading) {
                    if engine.isLoading {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar
            inputBar
        }
        .onAppear {
            engine.preloadModelIfNeeded()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.6))

            Text("Muse")
                .font(.title.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Ask anything. On-device AI, private by default.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if engine.isModelReady {
                Label("On-device only", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                setupBanner
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var setupBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(engine.loadingStatus.isEmpty ? "Setting up..." : engine.loadingStatus)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            Text("First-time setup downloads Llama 3.2 1B (~700 MB). Wi-Fi recommended.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    // MARK: - User bubble

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .contextMenu {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = text
                        #endif
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
    }

    // MARK: - Response

    private func responseSection(_ response: MuseResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            markdownView(response.answer)
        }
        .contextMenu {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = response.answer
                #endif
            } label: {
                Label("Copy response", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Markdown renderer

    @ViewBuilder
    private func markdownView(_ text: String) -> some View {
        let blocks = parseBlocks(text)
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            if block.isCode {
                codeBlock(block.content, language: block.language)
            } else {
                // Use iOS built-in markdown rendering
                if let attributed = try? AttributedString(markdown: block.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(block.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func codeBlock(_ code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = code
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color(white: 0.85))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, language.isEmpty ? 12 : 6)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Error

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text(engine.loadingStatus.isEmpty ? "Thinking..." : engine.loadingStatus)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if case let .unavailable(message) = speech.status {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField(inputPlaceholder, text: $prompt, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .focused($isPromptFocused)
                    .disabled(!engine.isModelReady || speech.status == .recording)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                micButton

                Button {
                    let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    prompt = ""
                    isPromptFocused = false
                    Task { await engine.ideate(prompt: text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(sendButtonEnabled ? .white : Color.gray.opacity(0.5))
                }
                .disabled(!sendButtonEnabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
        .onChange(of: speech.transcript) {
            guard speech.status == .recording else { return }
            let separator = promptBeforeRecording.isEmpty ? "" : " "
            prompt = promptBeforeRecording + separator + speech.transcript
        }
    }

    private var micButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            Image(systemName: speech.status == .recording ? "mic.fill" : "mic")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(micForeground)
                .frame(width: 36, height: 36)
                .background(speech.status == .recording ? Color.red.opacity(0.25) : Color.clear)
                .clipShape(Circle())
        }
        .disabled(!engine.isModelReady || engine.isLoading)
    }

    private var micForeground: Color {
        if !engine.isModelReady || engine.isLoading { return Color.gray.opacity(0.5) }
        if speech.status == .recording { return .red }
        return .white
    }

    private func toggleRecording() async {
        if speech.status == .recording {
            speech.stop()
        } else {
            promptBeforeRecording = prompt
            await speech.start()
        }
    }

    private var inputPlaceholder: String {
        if !engine.isModelReady { return "Setting up Muse..." }
        if speech.status == .recording { return "Listening..." }
        return "Reply to Muse..."
    }

    private var sendButtonEnabled: Bool {
        engine.isModelReady
            && !engine.isLoading
            && speech.status != .recording
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Block parser

    private struct ContentBlock {
        let content: String
        let isCode: Bool
        let language: String
    }

    private func parseBlocks(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentLines: [String] = []
        var inCode = false
        var codeLang = ""

        for line in lines {
            if !inCode && line.hasPrefix("```") {
                let prose = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !prose.isEmpty {
                    blocks.append(ContentBlock(content: prose, isCode: false, language: ""))
                }
                currentLines = []
                inCode = true
                codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if inCode && line.hasPrefix("```") {
                let code = currentLines.joined(separator: "\n")
                blocks.append(ContentBlock(content: code, isCode: true, language: codeLang))
                currentLines = []
                inCode = false
                codeLang = ""
            } else {
                currentLines.append(line)
            }
        }

        let remaining = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            blocks.append(ContentBlock(content: remaining, isCode: inCode, language: inCode ? codeLang : ""))
        }

        return blocks
    }
}
