import Foundation
import AVFoundation

public final class AudioMixingService: AudioMixingServiceProtocol, Sendable {
    public init() {}

    public func assembleDialogueTrack(
        segments: [DialogueTimelineSegment],
        totalDuration: Double,
        to outputURL: URL
    ) async throws -> URL {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let sampleRate: Double = 48000.0
        let totalSamples = max(1, Int(round(totalDuration * sampleRate)))

        // 48kHz mono float audio buffer
        var masterBuffer = [Float](repeating: 0.0, count: totalSamples)

        for seg in segments {
            guard FileManager.default.fileExists(atPath: seg.audioURL.path) else { continue }
            guard let file = try? AVAudioFile(forReading: seg.audioURL) else { continue }

            let fileFrames = AVAudioFrameCount(file.length)
            guard fileFrames > 0,
                  let pcmBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: fileFrames) else { continue }

            try? file.read(into: pcmBuffer)
            guard let floatData = pcmBuffer.floatChannelData else { continue }

            let startSample = Int(seg.startTime * sampleRate)
            let fileRate = file.processingFormat.sampleRate
            let channel = floatData[0]

            // Copy samples with sample rate adjustment
            let count = Int(fileFrames)
            for j in 0..<count {
                let targetSample = startSample + Int(Double(j) * (sampleRate / fileRate))
                if targetSample >= 0 && targetSample < totalSamples {
                    masterBuffer[targetSample] += channel[j]
                }
            }
        }

        // Prevent digital clipping
        var maxPeak: Float = 0.0
        for sample in masterBuffer {
            let absVal = abs(sample)
            if absVal > maxPeak {
                maxPeak = absVal
            }
        }

        if maxPeak > 0.95 {
            let scale = 0.95 / maxPeak
            for i in 0..<masterBuffer.count {
                masterBuffer[i] *= scale
            }
        }

        // Write to output 48kHz stereo 24-bit WAV using bounded streaming chunks
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false) else {
            throw AnimeDubError.audioMixingFailed("Could not create master audio format.")
        }

        let audioFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)

        let chunkSize = 240_000 // 5-second chunk at 48kHz
        guard let chunkBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(chunkSize)) else {
            throw AnimeDubError.audioMixingFailed("Could not allocate master audio mixing chunk buffer.")
        }

        var offset = 0
        while offset < totalSamples {
            let framesToWrite = min(chunkSize, totalSamples - offset)
            chunkBuffer.frameLength = AVAudioFrameCount(framesToWrite)
            if let outChannels = chunkBuffer.floatChannelData {
                masterBuffer.withUnsafeBufferPointer { ptr in
                    guard let base = ptr.baseAddress else { return }
                    outChannels[0].initialize(from: base.advanced(by: offset), count: framesToWrite)
                    outChannels[1].initialize(from: base.advanced(by: offset), count: framesToWrite)
                }
            }
            try audioFile.write(from: chunkBuffer)
            offset += framesToWrite
        }

        return outputURL
    }

    public func mixMasterSoundtrack(
        dialogueURL: URL,
        backgroundURL: URL?,
        to outputURL: URL,
        preserveBGM: Bool = true,
        normalizeLoudness: Bool = true
    ) async throws -> URL {
        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let hasBackground = backgroundURL != nil && FileManager.default.fileExists(atPath: backgroundURL!.path) && preserveBGM

        var args: [String] = ["-y", "-i", dialogueURL.path]

        if hasBackground {
            args.append(contentsOf: ["-i", backgroundURL!.path])
            var filter = "[1:a]volume=0.55[bg];[0:a]volume=1.0[voc];[voc][bg]amix=inputs=2:duration=longest[mixed]"
            if normalizeLoudness {
                filter += ";[mixed]loudnorm=I=-23:TP=-1.0:LRA=11[out]"
                args.append(contentsOf: ["-filter_complex", filter, "-map", "[out]"])
            } else {
                args.append(contentsOf: ["-filter_complex", filter, "-map", "[mixed]"])
            }
        } else {
            if normalizeLoudness {
                args.append(contentsOf: ["-af", "loudnorm=I=-23:TP=-1.0:LRA=11"])
            }
        }

        args.append(contentsOf: [
            "-acodec", "pcm_s24le",
            "-ar", "48000",
            "-ac", "2",
            outputURL.path
        ])

        let res = try await ProcessRunner.run(executable: "ffmpeg", arguments: args)
        guard res.isSuccess && FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AnimeDubError.audioMixingFailed("Master soundtrack mixing failed: \(res.stderr)")
        }

        return outputURL
    }
}
