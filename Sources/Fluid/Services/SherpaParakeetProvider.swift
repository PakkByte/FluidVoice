import Foundation
import SherpaOnnxRuntime

final class SherpaParakeetProvider: TranscriptionProvider {
    static let streamingPreviewMaxSamples = 8 * 16_000
    private static let streamingSessionSignatureSampleCount = 4096

    let name = "Parakeet (Intel CPU)"
    var isAvailable: Bool {
        CPUArchitecture.isIntel
    }

    private let stateLock = NSLock()
    private let decodeLock = NSLock()
    private let streamingPreviewLock = NSLock()
    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var streamingPreviewState: StreamingPreviewState?
    private let modelOverride: SettingsStore.SpeechModel?

    private struct StreamingPreviewState {
        let sampleCount: Int
        let sessionSignature: [Float]
        let text: String
    }

    init(modelOverride: SettingsStore.SpeechModel? = nil) {
        self.modelOverride = modelOverride
    }

    private var selectedModel: SettingsStore.SpeechModel {
        self.modelOverride ?? SettingsStore.shared.selectedSpeechModel
    }

    private var spec: SherpaParakeetModelSpec? {
        SherpaParakeetModelRegistry.spec(for: self.selectedModel)
    }

    private var cacheDirectory: URL? {
        SherpaParakeetModelRegistry.cacheDirectory(for: self.selectedModel)
    }

    var isReady: Bool {
        self.stateLock.withLock { self.recognizer != nil }
    }

    func modelsExistOnDisk() -> Bool {
        guard let spec, let cacheDirectory else { return false }
        return spec.artifactsAreComplete(at: cacheDirectory)
    }

    func prepare(progressHandler: ((ModelPreparationProgress) -> Void)?) async throws {
        try Task.checkCancellation()
        guard CPUArchitecture.isIntel else {
            throw Self.makeError("Sherpa's Parakeet path is only selected on Intel Macs.")
        }
        guard let spec, let cacheDirectory else {
            throw Self.makeError("The selected model is not supported by Sherpa ONNX.")
        }
        if self.isReady {
            return
        }

        var checksumVerified = false
        if spec.artifactsAreComplete(at: cacheDirectory) {
            progressHandler?(.optimizing)
            do {
                let checksumTask = Task.detached(priority: .utility) {
                    try await spec.verifyChecksums(at: cacheDirectory)
                }
                try await withTaskCancellationHandler(
                    operation: { try await checksumTask.value },
                    onCancel: { checksumTask.cancel() }
                )
                checksumVerified = true
            } catch {
                Self.removeArtifacts(spec.artifacts, from: cacheDirectory)
            }
        }

        if !spec.artifactsAreComplete(at: cacheDirectory) {
            progressHandler?(.preparingDownload)
            let downloader = HuggingFaceModelDownloader(
                owner: spec.repositoryOwner,
                repo: spec.repositoryName,
                revision: spec.revision,
                requiredItems: spec.requiredItems
            )
            try await downloader.ensureModelsPresent(at: cacheDirectory) { progress, _ in
                progressHandler?(.downloading(progress))
            }
        }

        guard spec.artifactsAreComplete(at: cacheDirectory) else {
            throw Self.makeError("Parakeet model files are incomplete. Delete the model and download it again.")
        }
        try Task.checkCancellation()
        if !checksumVerified {
            progressHandler?(.optimizing)
            do {
                let checksumTask = Task.detached(priority: .utility) {
                    try await spec.verifyChecksums(at: cacheDirectory)
                }
                try await withTaskCancellationHandler(
                    operation: { try await checksumTask.value },
                    onCancel: { checksumTask.cancel() }
                )
            } catch {
                Self.removeArtifacts(spec.artifacts, from: cacheDirectory)
                throw error
            }
        }
        try Task.checkCancellation()
        progressHandler?(.loading)

        let paths = SherpaOnnxTransducerPaths(
            encoder: cacheDirectory.appendingPathComponent("encoder.int8.onnx").path,
            decoder: cacheDirectory.appendingPathComponent("decoder.int8.onnx").path,
            joiner: cacheDirectory.appendingPathComponent("joiner.int8.onnx").path,
            tokens: cacheDirectory.appendingPathComponent("tokens.txt").path
        )
        let threadCount = max(1, min(ProcessInfo.processInfo.activeProcessorCount / 2, 6))
        let loadedRecognizer = try await Task.detached(priority: .userInitiated) {
            try SherpaOnnxOfflineRecognizer(paths: paths, threadCount: threadCount)
        }.value
        try Task.checkCancellation()
        self.stateLock.withLock { self.recognizer = loadedRecognizer }
        DebugLogger.shared.info(
            "Sherpa Parakeet ready [model=\(self.selectedModel.id), threads=\(threadCount)]",
            source: "SherpaParakeetProvider"
        )
    }

    func transcribe(_ samples: [Float]) async throws -> ASRTranscriptionResult {
        try await self.transcribeFinal(samples)
    }

    func transcribeFinal(_ samples: [Float]) async throws -> ASRTranscriptionResult {
        self.resetStreamingPreviewCache()
        return try self.decode(samples)
    }

    private func decode(_ samples: [Float]) throws -> ASRTranscriptionResult {
        guard !samples.isEmpty else { return ASRTranscriptionResult(text: "", confidence: 0) }
        guard let recognizer = self.stateLock.withLock({ self.recognizer }) else {
            throw Self.makeError("Parakeet is not loaded yet.")
        }
        let text = try self.decodeLock.withLock {
            try recognizer.decode(samples: samples)
        }.trimmingCharacters(in: .whitespacesAndNewlines)
        return ASRTranscriptionResult(text: text, confidence: text.isEmpty ? 0 : 1)
    }

    func transcribeStreaming(_ samples: [Float]) async throws -> ASRTranscriptionResult {
        let sessionSignature = Self.streamingSessionSignature(from: samples)
        let previewSamples = Self.streamingPreviewSamples(from: samples)

        return try self.streamingPreviewLock.withLock {
            if let state = self.streamingPreviewState,
               Self.startsNewStreamingSession(
                   samples: samples,
                   sessionSignature: sessionSignature,
                   after: state
               )
            {
                self.streamingPreviewState = nil
            }

            let result = try self.decode(previewSamples)
            let mergedText = Self.mergedStreamingPreview(
                previous: self.streamingPreviewState?.text ?? "",
                current: result.text
            )
            self.streamingPreviewState = StreamingPreviewState(
                sampleCount: samples.count,
                sessionSignature: sessionSignature,
                text: mergedText
            )
            return ASRTranscriptionResult(
                text: mergedText,
                confidence: mergedText.isEmpty ? 0 : result.confidence
            )
        }
    }

    static func streamingPreviewSamples(from samples: [Float]) -> [Float] {
        Array(samples.suffix(self.streamingPreviewMaxSamples))
    }

    static func mergedStreamingPreview(previous: String, current: String) -> String {
        let previousWords = previous.split(whereSeparator: \.isWhitespace)
        let currentWords = current.split(whereSeparator: \.isWhitespace)

        guard !currentWords.isEmpty else { return previous }
        guard !previousWords.isEmpty else { return currentWords.joined(separator: " ") }

        let overlap = stride(
            from: min(previousWords.count, currentWords.count),
            through: 1,
            by: -1
        ).first { count in
            zip(previousWords.suffix(count), currentWords.prefix(count)).allSatisfy {
                Self.normalizedPreviewWord($0) == Self.normalizedPreviewWord($1)
            }
        } ?? 0

        return (previousWords + currentWords.dropFirst(overlap)).joined(separator: " ")
    }

    func resetStreamingPreviewCache() {
        self.streamingPreviewLock.withLock {
            self.streamingPreviewState = nil
        }
    }

    func clearCache() async throws {
        self.resetStreamingPreviewCache()
        self.stateLock.withLock { self.recognizer = nil }
        guard let cacheDirectory, FileManager.default.fileExists(atPath: cacheDirectory.path) else { return }
        try FileManager.default.removeItem(at: cacheDirectory)
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(
            domain: "SherpaParakeetProvider",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func removeArtifacts(
        _ artifacts: [SherpaParakeetModelSpec.Artifact],
        from directory: URL
    ) {
        for artifact in artifacts {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(artifact.path))
        }
    }

    private static func streamingSessionSignature(from samples: [Float]) -> [Float] {
        Array(samples.prefix(self.streamingSessionSignatureSampleCount))
    }

    private static func startsNewStreamingSession(
        samples: [Float],
        sessionSignature: [Float],
        after state: StreamingPreviewState
    ) -> Bool {
        samples.count < state.sampleCount || sessionSignature != state.sessionSignature
    }

    private static func normalizedPreviewWord(_ word: Substring) -> String {
        word.trimmingCharacters(in: .punctuationCharacters).lowercased()
    }
}
