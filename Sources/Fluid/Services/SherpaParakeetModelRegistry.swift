import CryptoKit
import Foundation

struct SherpaParakeetModelSpec: Equatable, Sendable {
    struct Artifact: Equatable, Sendable {
        let path: String
        let byteCount: Int64
        let sha256: String
    }

    let repositoryOwner: String
    let repositoryName: String
    let revision: String
    let cacheFolderName: String
    let artifacts: [Artifact]

    var expectedDownloadBytes: Int64 {
        self.artifacts.reduce(0) { $0 + $1.byteCount }
    }

    var requiredItems: [HuggingFaceModelDownloader.ModelItem] {
        self.artifacts.map { .init(path: $0.path, isDirectory: false) }
    }

    func artifactsAreComplete(at directory: URL) -> Bool {
        self.artifacts.allSatisfy { artifact in
            let url = directory.appendingPathComponent(artifact.path)
            guard
                HuggingFaceModelDownloader.artifactIsComplete(at: url, isDirectory: false),
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                let size = attributes[.size] as? NSNumber
            else {
                return false
            }
            return size.int64Value == artifact.byteCount
        }
    }

    func verifyChecksums(at directory: URL) async throws {
        for artifact in self.artifacts {
            try Task.checkCancellation()
            let url = directory.appendingPathComponent(artifact.path)
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                try Task.checkCancellation()
                hasher.update(data: chunk)
            }
            try Task.checkCancellation()
            let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == artifact.sha256 else {
                throw NSError(
                    domain: "SherpaParakeetModelRegistry",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "The downloaded \(artifact.path) file failed its security check."]
                )
            }
        }
    }
}

enum SherpaParakeetModelRegistry {
    static let v2 = SherpaParakeetModelSpec(
        repositoryOwner: "csukuangfj",
        repositoryName: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8",
        revision: "1ab9323565ddb038682214b292f588070a538ce2",
        cacheFolderName: "parakeet-tdt-v2-int8-sherpa-onnx",
        artifacts: [
            .init(path: "encoder.int8.onnx", byteCount: 652_184_296, sha256: "a32b12d17bbbc309d0686fbbcc2987b5e9b8333a7da83fa6b089f0a2acd651ab"),
            .init(path: "decoder.int8.onnx", byteCount: 7_257_753, sha256: "b6bb64963457237b900e496ee9994b59294526439fbcc1fecf705b31a15c6b4e"),
            .init(path: "joiner.int8.onnx", byteCount: 1_739_080, sha256: "7946164367946e7f9f29a122407c3252b680dbae9a51343eb2488d057c3c43d2"),
            .init(path: "tokens.txt", byteCount: 9384, sha256: "ec182b70dd42113aff6c5372c75cac58c952443eb22322f57bbd7f53977d497d"),
        ]
    )

    static let v3 = SherpaParakeetModelSpec(
        repositoryOwner: "csukuangfj",
        repositoryName: "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8",
        revision: "2bda32ec70b097a55adaa07d9a7173915b43cc78",
        cacheFolderName: "parakeet-tdt-v3-int8-sherpa-onnx",
        artifacts: [
            .init(path: "encoder.int8.onnx", byteCount: 652_184_281, sha256: "acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247"),
            .init(path: "decoder.int8.onnx", byteCount: 11_845_275, sha256: "179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e"),
            .init(path: "joiner.int8.onnx", byteCount: 6_355_277, sha256: "3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3"),
            .init(path: "tokens.txt", byteCount: 93_939, sha256: "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d"),
        ]
    )

    static func spec(for model: SettingsStore.SpeechModel) -> SherpaParakeetModelSpec? {
        switch model {
        case .parakeetTDT: return self.v3
        case .parakeetTDTv2: return self.v2
        default: return nil
        }
    }

    static func cacheDirectory(for model: SettingsStore.SpeechModel) -> URL? {
        guard
            let spec = self.spec(for: model),
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            return nil
        }
        return caches
            .appendingPathComponent("FluidVoice", isDirectory: true)
            .appendingPathComponent("SherpaOnnxModels", isDirectory: true)
            .appendingPathComponent(spec.cacheFolderName, isDirectory: true)
    }
}
