import SherpaOnnxRuntime
import XCTest

final class OfflineRecognizerTests: XCTestCase {
    func testMissingModelsReturnAnErrorInsteadOfCrashing() {
        let paths = SherpaOnnxTransducerPaths(
            encoder: "/missing/encoder.int8.onnx",
            decoder: "/missing/decoder.int8.onnx",
            joiner: "/missing/joiner.int8.onnx",
            tokens: "/missing/tokens.txt"
        )

        XCTAssertThrowsError(try SherpaOnnxOfflineRecognizer(paths: paths, threadCount: 2))
    }
}
