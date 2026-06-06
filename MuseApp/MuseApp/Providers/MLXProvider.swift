// MLXProvider.swift — On-device LLM via MLX Swift. Zero cost, fully offline.

import Foundation
import HuggingFace
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

class MLXProvider: ModelProvider, ObservableObject {
    let slug = "mlx"
    let name = "MLX Local"
    private let modelID: String
    private var container: ModelContainer?
    private var isModelLoaded = false

    @Published var status: String = ""
    @Published var downloadProgress: Double = 0

    init(modelID: String = "mlx-community/Llama-3.2-3B-Instruct-4bit") {
        self.modelID = modelID
    }

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        await MainActor.run { status = "Loading model..." }

        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
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
        await MainActor.run { status = "" }
    }

    func generate(prompt: String, system: String, maxTokens: Int) async throws -> ModelResult {
        try await loadModel()

        guard let container else {
            return ModelResult(name: name, slug: slug, content: "", error: "Model failed to load")
        }

        let start = CFAbsoluteTimeGetCurrent()

        let session = ChatSession(
            container,
            instructions: system,
            generateParameters: GenerateParameters(temperature: 0.7)
        )

        var output = ""
        var tokenCount = 0
        for try await text in session.streamResponse(to: prompt) {
            output += text
            tokenCount += 1
            if tokenCount >= maxTokens {
                break
            }
        }

        let latency = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        return ModelResult(
            name: name,
            slug: slug,
            content: output,
            providerType: "local",
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
