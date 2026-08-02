//
//  fluidApp.swift
//  fluid
//
//  Created by Barathwaj Anandan on 7/30/25.
//

import AppKit
import ApplicationServices
import SwiftUI

struct FluidApp: App {
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var appServices: AppServices
    @ObservedObject private var settings = SettingsStore.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Use the shared singleton instance
        _appServices = StateObject(wrappedValue: AppServices.shared)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            AdaptiveAppTheme(accent: self.settings.accentColor) {
                ContentView()
                    .environmentObject(self.menuBarManager)
                    .environmentObject(self.appServices)
            }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    self.menuBarManager.openPreferencesFromUI()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@main
enum FluidVoiceEntryPoint {
    private static let intelProviderSmokeArgument = "--fluidvoice-intel-provider-smoke"

    static func main() {
        if CommandLine.arguments.contains(self.intelProviderSmokeArgument) {
            self.runIntelProviderSmoke()
            return
        }

        FluidApp.main()
    }

    /// Validates the Intel-only Parakeet route before SwiftUI or AppKit starts a GUI session.
    private static func runIntelProviderSmoke() {
        #if arch(x86_64)
        guard CPUArchitecture.current == .intel else {
            self.failIntelProviderSmoke("CPUArchitecture did not report Intel.")
        }
        guard TranscriptionBackendRoute.route(for: .parakeetTDT) == .sherpaOnnx,
              TranscriptionBackendRoute.route(for: .parakeetTDTv2) == .sherpaOnnx
        else {
            self.failIntelProviderSmoke("Intel Parakeet models did not route to Sherpa ONNX.")
        }

        let provider = SherpaParakeetProvider(modelOverride: .parakeetTDT)
        guard provider.isAvailable else {
            Self.failIntelProviderSmoke("Sherpa Parakeet provider is unavailable on Intel.")
        }
        print("FluidVoice Intel Parakeet smoke check passed.")
        #else
        Self.failIntelProviderSmoke("Smoke check requires an x86_64 executable.")
        #endif
    }

    private static func failIntelProviderSmoke(_ message: String) -> Never {
        fputs("FluidVoice Intel Parakeet smoke check failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
