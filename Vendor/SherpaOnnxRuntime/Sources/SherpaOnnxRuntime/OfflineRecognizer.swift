import Foundation
import SherpaOnnxC

public enum SherpaOnnxRuntimeError: LocalizedError {
    case modelFileMissing(String)
    case recognizerCreationFailed
    case streamCreationFailed
    case recognitionFailed
    case sampleCountTooLarge

    public var errorDescription: String? {
        switch self {
        case let .modelFileMissing(path):
            return "Sherpa model file is missing or empty: \(path)"
        case .recognizerCreationFailed:
            return "Sherpa could not load the Parakeet model."
        case .streamCreationFailed:
            return "Sherpa could not create a transcription stream."
        case .recognitionFailed:
            return "Sherpa did not return a transcription result."
        case .sampleCountTooLarge:
            return "The recording is too large for one Sherpa transcription pass."
        }
    }
}

public struct SherpaOnnxTransducerPaths: Sendable {
    public let encoder: String
    public let decoder: String
    public let joiner: String
    public let tokens: String

    public init(encoder: String, decoder: String, joiner: String, tokens: String) {
        self.encoder = encoder
        self.decoder = decoder
        self.joiner = joiner
        self.tokens = tokens
    }

    fileprivate func validate() throws {
        for path in [self.encoder, self.decoder, self.joiner, self.tokens] {
            guard
                let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                let size = attributes[.size] as? NSNumber,
                size.int64Value > 0
            else {
                throw SherpaOnnxRuntimeError.modelFileMissing(path)
            }
        }
    }
}

/// A small throwing wrapper over Sherpa's offline C API. The recognizer is intentionally
/// serialized by FluidVoice's transcription executor; callers must not decode concurrently.
public final class SherpaOnnxOfflineRecognizer: @unchecked Sendable {
    private let recognizer: OpaquePointer

    public init(paths: SherpaOnnxTransducerPaths, threadCount: Int) throws {
        try paths.validate()

        var created: OpaquePointer?
        paths.encoder.withCString { encoder in
            paths.decoder.withCString { decoder in
                paths.joiner.withCString { joiner in
                    paths.tokens.withCString { tokens in
                        "cpu".withCString { provider in
                            "nemo_transducer".withCString { modelType in
                                "greedy_search".withCString { decodingMethod in
                                    var config = SherpaOnnxOfflineRecognizerConfig()
                                    config.feat_config.sample_rate = 16_000
                                    config.feat_config.feature_dim = 80
                                    config.model_config.transducer.encoder = encoder
                                    config.model_config.transducer.decoder = decoder
                                    config.model_config.transducer.joiner = joiner
                                    config.model_config.tokens = tokens
                                    config.model_config.num_threads = Int32(max(1, min(threadCount, 8)))
                                    config.model_config.provider = provider
                                    config.model_config.model_type = modelType
                                    config.decoding_method = decodingMethod
                                    created = SherpaOnnxCreateOfflineRecognizer(&config)
                                }
                            }
                        }
                    }
                }
            }
        }

        guard let created else {
            throw SherpaOnnxRuntimeError.recognizerCreationFailed
        }
        self.recognizer = created
    }

    deinit {
        SherpaOnnxDestroyOfflineRecognizer(self.recognizer)
    }

    public func decode(samples: [Float], sampleRate: Int32 = 16_000) throws -> String {
        guard samples.count <= Int(Int32.max) else {
            throw SherpaOnnxRuntimeError.sampleCountTooLarge
        }
        guard let stream = SherpaOnnxCreateOfflineStream(self.recognizer) else {
            throw SherpaOnnxRuntimeError.streamCreationFailed
        }
        defer { SherpaOnnxDestroyOfflineStream(stream) }

        samples.withUnsafeBufferPointer { buffer in
            SherpaOnnxAcceptWaveformOffline(stream, sampleRate, buffer.baseAddress, Int32(buffer.count))
        }
        SherpaOnnxDecodeOfflineStream(self.recognizer, stream)

        guard let result = SherpaOnnxGetOfflineStreamResult(stream) else {
            throw SherpaOnnxRuntimeError.recognitionFailed
        }
        defer { SherpaOnnxDestroyOfflineRecognizerResult(result) }
        guard let text = result.pointee.text else { return "" }
        return String(cString: text)
    }
}
