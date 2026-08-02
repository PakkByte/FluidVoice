# Current Status

Date: 2026-08-01

- Baseline: FluidVoice v1.6.6, synced with `altic-dev/FluidVoice` main at `09ad577`.
- Active work: Intel Parakeet TDT v2/v3 support through Sherpa ONNX CPU inference is implemented on a feature branch.
- Branch: `agent/intel-parakeet-sherpa`.
- Confirmed: the pinned Sherpa ONNX wrapper builds on x86_64 macOS, rejects missing model files without crashing, and the real Parakeet v2 INT8 model transcribed the bundled fixture as `Hello Fluid Voice.` in about 0.15 seconds of decode time on the Intel development Mac.
- Confirmed: Xcode 26.3 is installed, the full Intel app builds locally, focused Intel integration tests pass, and the macOS CI workflow passes on both Intel and Apple Silicon.
- Confirmed: the Parakeet `tokens.txt` downloader no longer mistakes valid angle-bracket vocabulary entries such as `<unk> 0` for HTML. The regression test first reproduced the failure and passes after the fix while the existing HTML-block-page tests remain green.
- Installed: the rebuilt, ad-hoc-signed Intel app is at `/Users/apple54/Applications/FluidVoice Intel.app`; Parakeet TDT v2 (Blazing Fast - English) is downloaded and active.
- Pull request: `https://github.com/PakkByte/FluidVoice/pull/1`.
