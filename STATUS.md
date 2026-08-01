# Current Status

Date: 2026-08-01

- Baseline: FluidVoice v1.6.6, synced with `altic-dev/FluidVoice` main at `09ad577`.
- Active work: Intel Parakeet TDT v2/v3 support through Sherpa ONNX CPU inference is implemented on a feature branch.
- Branch: `agent/intel-parakeet-sherpa`.
- Confirmed: the pinned Sherpa ONNX wrapper builds on x86_64 macOS, rejects missing model files without crashing, and the real Parakeet v2 INT8 model transcribed the bundled fixture as `Hello Fluid Voice.` in about 0.15 seconds of decode time on the Intel development Mac.
- Pending: full Xcode app/test execution. The installed Command Line Tools lack SwiftUI macro plugins; Xcode 26.3 is compatible with macOS 15.7.8 but requires the owner to sign in to Apple Developer Downloads and provide enough disk space to unpack it.
- CI: the macOS workflow builds and tests both Intel and Apple Silicon using Xcode 26.3.
