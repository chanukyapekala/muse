// MLXProvider.swift — On-device LLM via MLX Swift. Zero cost, fully offline.

import Foundation
import HuggingFace
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers
#if os(iOS)
import UIKit
#endif

class MLXProvider: ModelProvider, ObservableObject {
    let slug = "mlx"
    let name = "MLX Local"
    private let modelID: String
    private var container: ModelContainer?
    private var isModelLoaded = false

    @Published var status: String = ""
    @Published var downloadProgress: Double = 0
    @Published var isReady: Bool = false

    init(modelID: String = "mlx-community/Llama-3.2-1B-Instruct-4bit") {
        self.modelID = modelID
    }

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        await MainActor.run { status = "Loading model..." }

        MLX.GPU.set(cacheLimit: 128 * 1024 * 1024)
        let config = ModelConfiguration(id: modelID)

        let downloader = HubBridge(HubClient()) { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted
                self?.status = "Downloading model: \(Int(progress.fractionCompleted * 100))%"
            }
        }
        let tokenizerLoader = TransformersTokenizerLoader()

        container = try await LLMModelFactory.shared.loadContainer(
            from: downloader,
            using: tokenizerLoader,
            configuration: config
        )
        isModelLoaded = true
        await MainActor.run {
            status = ""
            isReady = true
        }
    }

    func generate(prompt: String, system: String, maxTokens: Int) async throws -> ModelResult {
        try await loadModel()

        guard let container else {
            return ModelResult(name: name, slug: slug, content: "", error: "Model failed to load")
        }

        // iOS denies GPU command submission once the app is backgrounded; request
        // a background-task token so a short generation can finish, and bail
        // gracefully if iOS revokes it mid-stream.
        #if os(iOS)
        let bgTaskID: UIBackgroundTaskIdentifier = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "MLX inference")
        }
        defer {
            if bgTaskID != .invalid {
                Task { @MainActor in
                    UIApplication.shared.endBackgroundTask(bgTaskID)
                }
            }
        }
        #endif

        let start = CFAbsoluteTimeGetCurrent()

        let session = ChatSession(
            container,
            instructions: system,
            generateParameters: GenerateParameters(temperature: 0.7)
        )

        var output = ""
        var tokenCount = 0
        do {
            for try await text in session.streamResponse(to: prompt) {
                output += text
                tokenCount += 1
                if tokenCount >= maxTokens {
                    break
                }
            }
        } catch {
            // Most commonly: app went to background and Metal refused further
            // GPU submissions. Return whatever we have rather than losing it.
            if output.isEmpty { throw error }
            return ModelResult(
                name: name,
                slug: slug,
                content: output,
                error: "Stopped early — app was backgrounded.",
                latencyMs: Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            )
        }

        let latency = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        return ModelResult(
            name: name,
            slug: slug,
            content: output,
            latencyMs: latency
        )
    }

    func isAvailable() -> Bool {
        return true
    }
}

// MARK: - Bridge HuggingFace SDK → MLXLMCommon.Downloader

private struct HubBridge: MLXLMCommon.Downloader {
    private let upstream: HuggingFace.HubClient
    private let onProgress: @Sendable (Progress) -> Void

    init(_ upstream: HuggingFace.HubClient, onProgress: @Sendable @escaping (Progress) -> Void = { _ in }) {
        self.upstream = upstream
        self.onProgress = onProgress
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Foundation.Progress) -> Void
    ) async throws -> URL {
        guard let repoID = HuggingFace.Repo.ID(rawValue: id) else {
            throw MLXProviderError.invalidRepositoryID(id)
        }
        let rev = revision ?? "main"
        let onProgress = self.onProgress
        return try await upstream.downloadSnapshot(
            of: repoID,
            revision: rev,
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
                onProgress(progress)
            }
        )
    }
}

// MARK: - Bridge swift-transformers → MLXLMCommon.TokenizerLoader

private struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(upstream)
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

// MARK: - Errors

private enum MLXProviderError: LocalizedError {
    case invalidRepositoryID(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            return "Invalid Hugging Face repository ID: '\(id)'"
        }
    }
}
