// SpeechRecognizer.swift — On-device dictation via SFSpeechRecognizer.
// Audio never leaves the device: requiresOnDeviceRecognition = true.

import AVFoundation
import Foundation
import Speech

@MainActor
class SpeechRecognizer: ObservableObject {
    enum Status: Equatable {
        case idle
        case unavailable(String)
        case recording
    }

    @Published var status: Status = .idle
    @Published var transcript: String = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var committedTranscript: String = ""

    var supportsOnDevice: Bool {
        recognizer?.supportsOnDeviceRecognition ?? false
    }

    func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }

        #if os(iOS)
        return await AVAudioApplication.requestRecordPermission()
        #else
        return false
        #endif
    }

    func start() async {
        guard status != .recording else { return }

        let granted = await requestAuthorization()
        guard granted else {
            status = .unavailable("Microphone or speech permission denied. Enable in Settings.")
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            status = .unavailable("Speech recognition unavailable on this device.")
            return
        }

        guard recognizer.supportsOnDeviceRecognition else {
            status = .unavailable("On-device dictation not installed. Settings → General → Keyboard → Dictation.")
            return
        }

        do {
            try configureAudioSession()
            try startEngine(recognizer: recognizer)
            status = .recording
            transcript = ""
            committedTranscript = ""
        } catch {
            status = .unavailable(error.localizedDescription)
        }
    }

    func stop() {
        guard status == .recording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        status = .idle

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func startEngine(recognizer: SFSpeechRecognizer) throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        startRecognitionRequest(recognizer: recognizer)
    }

    private func startRecognitionRequest(recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    let utterance = result.bestTranscription.formattedString
                    let separator = self.committedTranscript.isEmpty ? "" : " "
                    self.transcript = self.committedTranscript + separator + utterance

                    if result.isFinal {
                        self.committedTranscript += separator + utterance
                        self.transcript = self.committedTranscript
                        // Start a fresh request so further speech is captured.
                        // Don't cancel the current task — it's already wrapping up; cancel
                        // confuses the recognizer's state machine.
                        if self.status == .recording {
                            self.startRecognitionRequest(recognizer: recognizer)
                        }
                        return
                    }
                }

                if error != nil {
                    self.stop()
                }
            }
        }
    }
}
