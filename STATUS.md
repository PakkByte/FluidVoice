# Current Status

Date: 2026-08-02

- Baseline: FluidVoice v1.6.6, synced with `altic-dev/FluidVoice` main at `09ad577`.
- Active work: Intel feature parity is implemented where the public dependencies support x86_64: the complete visible speech-model list, live previews, media pause/resume, and dictionary endpoint detection.
- Branch: `agent/intel-parakeet-sherpa`.
- Confirmed: the pinned Sherpa ONNX wrapper builds on x86_64 macOS, rejects missing model files without crashing, and the real Parakeet v2 INT8 model transcribed the bundled fixture as `Hello Fluid Voice.` in about 0.15 seconds of decode time on the Intel development Mac.
- Confirmed: Xcode 26.3 builds the complete Intel app and its integration-test bundle; the built x86_64 app passes the non-GUI Sherpa routing smoke check; and the GitHub Intel and Apple Silicon jobs both pass.
- Confirmed: the Parakeet `tokens.txt` downloader no longer mistakes valid angle-bracket vocabulary entries such as `<unk> 0` for HTML. The regression test first reproduced the failure and passes after the fix while the existing HTML-block-page tests remain green.
- Confirmed: Parakeet Flash loaded its exact Core ML model and transcribed the bundled fixture on the Intel development Mac.
- Confirmed: Nemotron Speech 3.5 loaded its exact Core ML model and transcribed a 5.8-second local probe on Intel. It took about 38 seconds, so the UI labels this path as an Intel preview rather than promising Apple Silicon speed.
- Partially confirmed: Cohere Transcribe now compiles for Intel and uses CPU/GPU compute, but its first-time Core ML compilation exhausted the available temporary disk space during the local runtime probe. The UI warns Intel users about this storage requirement.
- Unavoidable hardware/OS difference: Apple Speech Analyzer still requires macOS 26, which this 2018 Intel Mac cannot install. Apple Speech Legacy remains available.
- Installed: the latest normal (non-test) x86_64 build is signed with the owner's Apple Development certificate, uses the owner-controlled bundle identifier `com.pakkbyte.FluidVoiceIntel`, explicitly carries the Audio Input entitlement, and is verified at `/Applications/FluidVoice Intel.app`; macOS Microphone access is granted, and Parakeet TDT v2 (Blazing Fast - English) remains downloaded and active. Xcode 26.3 is installed at `/Applications/Xcode-26.3.0.app` and selected as the system developer tool. Earlier FluidVoice builds are recoverably stored in Trash as `FluidVoice Intel-before-parity-2026-08-01.app` and `FluidVoice Intel-before-stable-signing-2026-08-02.app`.
- Review hardening: Intel live previews keep earlier text while decoding a bounded eight-second window, checksum cancellation propagates into background hashing, and CI exercises the real Intel app/provider route.
- Privacy: anonymous analytics and automatic update checks are disabled for the installed personal build; the source default for anonymous analytics is OFF on this branch.
- Pull request: `https://github.com/PakkByte/FluidVoice/pull/1`.
