// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SherpaOnnxRuntime",
    platforms: [.macOS("15.0")],
    products: [
        .library(name: "SherpaOnnxRuntime", targets: ["SherpaOnnxRuntime"]),
    ],
    targets: [
        .binaryTarget(
            name: "SherpaOnnxC",
            url: "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.4/sherpa-onnx-v1.13.4-macos.xcframework.zip",
            checksum: "4325d8aed99b94be58969005b19f9626f3f3afc4ebd42378b0aad2b84e233552"
        ),
        .binaryTarget(
            name: "onnxruntime",
            url: "https://github.com/csukuangfj/onnxruntime-libs/releases/download/v1.27.1/onnxruntime-macos-static-xcframework-1.27.1.xcframework.zip",
            checksum: "89769c25a63985e2ab7a12e72215c173c5078e49dc4a2273cb84b75e587d7b96"
        ),
        .target(
            name: "SherpaOnnxRuntime",
            dependencies: ["SherpaOnnxC", "onnxruntime"],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreML"),
            ]
        ),
        .testTarget(
            name: "SherpaOnnxRuntimeTests",
            dependencies: ["SherpaOnnxRuntime"]
        ),
    ]
)
