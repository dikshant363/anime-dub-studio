import Foundation
import SwiftUI
import AnimeDubCore

public struct SettingsView: View {
    @ObservedObject var viewModel: StudioViewModel

    public init(viewModel: StudioViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("Apple Silicon & Machine Learning") {
                LabeledContent("Hardware Processor", value: viewModel.systemCaps.chipName)
                LabeledContent("Unified Memory", value: "\(Int(viewModel.systemCaps.totalMemoryGB)) GB Unified Architecture")
                LabeledContent("Apple Intelligence", value: viewModel.systemCaps.foundationModelsAvailable ? "Active (On-Device FoundationModels)" : "Unavailable: \(viewModel.systemCaps.foundationModelsReason)")
                LabeledContent("Speech Recognition (ASR)", value: "Apple Silicon MLX Whisper (Tiny / Large-v3-turbo)")
            }

            Section("Offline Indian Cast Voices (/usr/bin/say)") {
                ForEach(viewModel.systemCaps.availableIndianVoices, id: \.self) { voice in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.tint)
                        Text(voice)
                            .fontWeight(.medium)
                        Spacer()
                        Text("Installed On-Device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Multimedia Subsystems") {
                LabeledContent("FFmpeg Codec Engine", value: ProcessRunner.resolveExecutable(named: "ffmpeg") ?? "Missing")
                LabeledContent("FFprobe Stream Inspector", value: ProcessRunner.resolveExecutable(named: "ffprobe") ?? "Missing")
                LabeledContent("Loudness Compliance", value: "EBU R128 (-23 LUFS Target / -1.0 dB True Peak)")
                LabeledContent("Video Stream Handling", value: "Lossless Stream-Copy (-c:v copy)")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
