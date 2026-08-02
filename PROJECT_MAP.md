# Project Map

- `Sources/Fluid/`: FluidVoice macOS application source.
- `Sources/CoreAudioCaptureSupport/`: native audio capture support module.
- `Tests/FluidDictationIntegrationTests/`: app behavior and integration tests.
- `Vendor/`: pinned, repo-local package manifests and source bridges for binary dependencies; no downloaded binaries are committed.
- `Fluid.xcodeproj/`: shipping Xcode project and package resolution.
- `Package.swift`: Swift Package Manager build definition.
- `STATUS.md`: dated current implementation and verification status.
- `DerivedData/`: generated local build output; not source.
