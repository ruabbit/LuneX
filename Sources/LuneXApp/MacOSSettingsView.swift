#if os(macOS)
import AppKit
import SwiftUI

struct MacOSSettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        TabView {
            generalSettings($appModel)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            streamSettings($appModel)
                .tabItem {
                    Label("Stream", systemImage: "display")
                }

            inputSettings($appModel)
                .tabItem {
                    Label("Input", systemImage: "cursorarrow.motionlines")
                }

            audioSettings($appModel)
                .tabItem {
                    Label("Audio", systemImage: "wave.3.right.circle")
                }
        }
        .frame(width: 580, height: 430)
        .onChange(of: appModel.settings) { _, _ in
            Task {
                await appModel.saveSettings()
            }
        }
        .onChange(of: appModel.settings.audio) { _, audio in
            Task {
                do {
                    try await appModel.updateSpatialAudioPreferences(
                        audio.sessionPreferences
                    )
                } catch {
                    appModel.diagnostics.record(
                        ApplicationDiagnosticFactory.streamFailure(error)
                    )
                }
            }
        }
    }

    private func generalSettings(_ appModel: Bindable<AppModel>) -> some View {
        Form {
            Section("Hosts") {
                Toggle(
                    "Discover Sunshine hosts automatically",
                    isOn: appModel.settings.discoveryEnabled
                )
            }

            Section("Diagnostics") {
                Toggle(
                    "Record diagnostics",
                    isOn: appModel.settings.diagnosticsEnabled
                )
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private func streamSettings(_ appModel: Bindable<AppModel>) -> some View {
        Form {
            Section("Stream Quality") {
                Picker("Resolution", selection: resolutionChoiceBinding) {
                    ForEach(resolutionChoices, id: \.self) { choice in
                        Text(resolutionLabel(choice)).tag(choice)
                    }
                }

                Picker(
                    "Frame rate",
                    selection: appModel.settings.stream.frameRate
                ) {
                    ForEach(frameRateOptions, id: \.self) { frameRate in
                        Text("\(frameRate) fps").tag(frameRate)
                    }
                }

                LabeledContent("Bitrate") {
                    HStack(spacing: 12) {
                        Slider(
                            value: bitrateBinding,
                            in: 10...200,
                            step: 5
                        )
                        .frame(width: 230)
                        Text("\(appModel.wrappedValue.settings.stream.bitrateKbps / 1_000) Mbps")
                            .monospacedDigit()
                            .frame(width: 72, alignment: .trailing)
                    }
                }

                Picker(
                    "Scaling",
                    selection: appModel.settings.stream.scaleMode
                ) {
                    ForEach(RenderScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }

                Toggle(
                    "HDR / EDR",
                    isOn: appModel.settings.stream.hdrEnabled
                )
            }

            Section("Current Output") {
                compactHDRStatus
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private func inputSettings(_ appModel: Bindable<AppModel>) -> some View {
        Form {
            Section("Mouse") {
                Toggle(
                    "Prefer relative mouse mode",
                    isOn: appModel.settings.input.preferRelativeMouseMode
                )
                Text("Relative mode captures pointer movement for games that control the camera directly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                LabeledContent("System shortcuts", value: "Always local")
                Text("macOS-reserved shortcuts remain on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private func audioSettings(_ appModel: Bindable<AppModel>) -> some View {
        Form {
            Section("Spatial Audio") {
                Toggle(
                    "Spatial audio",
                    isOn: appModel.settings.audio.spatialAudioEnabled
                )
                Toggle(
                    "Head tracking",
                    isOn: appModel.settings.audio.headTrackingEnabled
                )
                .disabled(!appModel.wrappedValue.settings.audio.spatialAudioEnabled)
            }

            Section("Current Playback") {
                compactSpatialAudioStatus
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private var compactHDRStatus: some View {
        let content = appModel.hdrPresentationStatus.content
        return VStack(alignment: .leading, spacing: 4) {
            Label(content.settingsValue, systemImage: content.systemImage)
            Text(content.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current HDR output")
        .accessibilityValue(content.accessibilityValue)
    }

    private var compactSpatialAudioStatus: some View {
        let content = appModel.spatialAudioPresentationStatus.content
        return VStack(alignment: .leading, spacing: 4) {
            Label(content.settingsValue, systemImage: content.systemImage)
            Text(content.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current spatial audio playback")
    }

    private var resolutionChoiceBinding: Binding<ProductMacOSResolutionChoice> {
        Binding(
            get: {
                ProductMacOSStreamSettingsOptions.selectedResolutionChoice(
                    nativeDisplaySize: nativeDisplaySize,
                    stored: storedResolution
                )
            },
            set: { choice in
                let size = choice.size
                appModel.settings.stream.width = size.width
                appModel.settings.stream.height = size.height
            }
        )
    }

    private var storedResolution: PixelSize {
        PixelSize(
            width: appModel.settings.stream.width,
            height: appModel.settings.stream.height
        )
    }

    private var bitrateBinding: Binding<Double> {
        Binding(
            get: { Double(appModel.settings.stream.bitrateKbps) / 1_000 },
            set: { appModel.settings.stream.bitrateKbps = Int($0 * 1_000) }
        )
    }

    private var resolutionChoices: [ProductMacOSResolutionChoice] {
        ProductMacOSStreamSettingsOptions.resolutionChoices(
            nativeDisplaySize: nativeDisplaySize,
            stored: storedResolution
        )
    }

    private func resolutionLabel(_ choice: ProductMacOSResolutionChoice) -> String {
        let size = choice.size
        return switch choice {
        case .preset where size == PixelSize(width: 1_920, height: 1_080):
            "1920 × 1080 (1080p)"
        case .preset where size == PixelSize(width: 2_560, height: 1_440):
            "2560 × 1440 (1440p)"
        case .preset where size == PixelSize(width: 3_840, height: 2_160):
            "3840 × 2160 (4K)"
        case .preset:
            "\(size.width) × \(size.height)"
        case .native:
            "Current Display (\(size.width) × \(size.height))"
        case .custom:
            "Custom (\(size.width) × \(size.height))"
        }
    }

    private var nativeDisplaySize: PixelSize? {
        guard let screen = NSScreen.main else { return nil }
        let scale = screen.backingScaleFactor
        return PixelSize(
            width: Int((screen.frame.width * scale).rounded()),
            height: Int((screen.frame.height * scale).rounded())
        )
    }

    private var frameRateOptions: [Int] {
        ProductMacOSStreamSettingsOptions.frameRates(
            stored: appModel.settings.stream.frameRate
        )
    }
}
#endif
