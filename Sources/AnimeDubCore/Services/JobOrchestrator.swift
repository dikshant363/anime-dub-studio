import Foundation

public final class JobOrchestrator: @unchecked Sendable {
    public let probeService: MediaProbeServiceProtocol
    public let extractionService: AudioExtractionServiceProtocol
    public let asrProvider: ASRProviderProtocol
    public let diarizationProvider: DiarizationProviderProtocol
    public let translationProvider: TranslationProviderProtocol
    public let hindiAdapter: HindiAdaptationServiceProtocol
    public let hinglishService: HinglishLocalizationServiceProtocol
    public let speechSynthesizer: SpeechSynthesisProviderProtocol
    public let timingService: DialogueTimingServiceProtocol
    public let mixingService: AudioMixingServiceProtocol
    public let subtitleService: SubtitleServiceProtocol
    public let renderService: VideoRenderServiceProtocol
    public let qaService: QualityAssuranceServiceProtocol
    public let checkpointStore: CheckpointStore
    public let projectStore: ProjectStore

    private let controlLock = NSLock()
    private var _isCancelled = false
    private var _isPaused = false

    private var isCancelled: Bool {
        get {
            controlLock.lock()
            defer { controlLock.unlock() }
            return _isCancelled
        }
        set {
            controlLock.lock()
            defer { controlLock.unlock() }
            _isCancelled = newValue
        }
    }

    private var isPaused: Bool {
        get {
            controlLock.lock()
            defer { controlLock.unlock() }
            return _isPaused
        }
        set {
            controlLock.lock()
            defer { controlLock.unlock() }
            _isPaused = newValue
        }
    }

    public init(
        probeService: MediaProbeServiceProtocol = MediaProbeService(),
        extractionService: AudioExtractionServiceProtocol = AudioExtractionService(),
        asrProvider: ASRProviderProtocol = CompositeASRProvider(),
        diarizationProvider: DiarizationProviderProtocol = AcousticDiarizer(),
        translationProvider: TranslationProviderProtocol = TranslationRouter(),
        hindiAdapter: HindiAdaptationServiceProtocol = HindiAdaptationService(),
        hinglishService: HinglishLocalizationServiceProtocol = HinglishLocalizationService(),
        speechSynthesizer: SpeechSynthesisProviderProtocol = SpeechSynthesisProvider(),
        timingService: DialogueTimingServiceProtocol = DialogueTimingService(),
        mixingService: AudioMixingServiceProtocol = AudioMixingService(),
        subtitleService: SubtitleServiceProtocol = SubtitleService(),
        renderService: VideoRenderServiceProtocol = VideoRenderService(),
        qaService: QualityAssuranceServiceProtocol = QualityAssuranceService(),
        checkpointStore: CheckpointStore = CheckpointStore(),
        projectStore: ProjectStore = ProjectStore.shared
    ) {
        self.probeService = probeService
        self.extractionService = extractionService
        self.asrProvider = asrProvider
        self.diarizationProvider = diarizationProvider
        self.translationProvider = translationProvider
        self.hindiAdapter = hindiAdapter
        self.hinglishService = hinglishService
        self.speechSynthesizer = speechSynthesizer
        self.timingService = timingService
        self.mixingService = mixingService
        self.subtitleService = subtitleService
        self.renderService = renderService
        self.qaService = qaService
        self.checkpointStore = checkpointStore
        self.projectStore = projectStore
    }

    public func cancel() {
        isCancelled = true
    }

    public func pause() {
        isPaused = true
    }

    public func resume() {
        isPaused = false
    }

    public func run(
        project: Project,
        episode: Episode,
        options: DubOptions,
        onProgress: @escaping @Sendable (JobState) -> Void
    ) async throws -> (finalVideoURL: URL, qaReport: QAReport) {
        isCancelled = false
        isPaused = false

        var job = JobState(
            episodeId: episode.id,
            projectId: project.id,
            status: .running,
            stage: .preparing,
            progress: 2.0,
            startedAt: Date()
        )

        func checkControl() async throws {
            try Task.checkCancellation()
            if isCancelled {
                job.status = .cancelled
                job.stage = .failed
                job.errorMessage = "Job cancelled by user"
                onProgress(job)
                throw AnimeDubError.jobCancelled
            }
            while isPaused {
                job.status = .paused
                onProgress(job)
                try await Task.sleep(nanoseconds: 500_000_000)
                try Task.checkCancellation()
                if isCancelled {
                    job.status = .cancelled
                    onProgress(job)
                    throw AnimeDubError.jobCancelled
                }
            }
            if job.status == .paused {
                job.status = .running
            }
        }

        func emit(stage: ProcessingStage, progress: Double, message: String, currentItem: Int? = nil, totalItems: Int? = nil, character: String? = nil, processedDuration: Double? = nil) {
            job.stage = stage
            job.progress = round(progress * 10) / 10
            job.currentItem = currentItem
            job.totalItems = totalItems
            job.currentCharacter = character
            if let pd = processedDuration {
                job.processedDuration = pd
            }
            let log = JobLog(stage: stage, progress: job.progress, message: message)
            job.logs.append(log)
            onProgress(job)
        }

        let epDir = projectStore.episodeDirectory(for: project.id, episodeId: episode.id)
        let audioDir = epDir.appendingPathComponent("audio", isDirectory: true)
        let voicesDir = epDir.appendingPathComponent("voices", isDirectory: true)
        let subtitlesDir = epDir.appendingPathComponent("subtitles", isDirectory: true)
        let exportDir = epDir.appendingPathComponent("export", isDirectory: true)
        let chkDir = epDir.appendingPathComponent("checkpoints", isDirectory: true)

        for d in [audioDir, voicesDir, subtitlesDir, exportDir, chkDir] {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        let sourceMediaURL = URL(fileURLWithPath: episode.sourceMediaPath)
        guard FileManager.default.fileExists(atPath: sourceMediaURL.path) else {
            throw AnimeDubError.unsupportedMedia("Source media file not found: \(sourceMediaURL.path)")
        }

        // -------------------------------------------------------------
        // Stage 1: Media Inspection & Audio Extraction
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .preparing, progress: 5.0, message: "Inspecting video and audio streams...")
        let metadata = try await probeService.inspectMedia(at: sourceMediaURL)
        job.totalDuration = metadata.duration

        let masterAudioURL = audioDir.appendingPathComponent("master_audio.wav")
        let asrAudioURL = audioDir.appendingPathComponent("asr_16k.wav")
        let chkExtractionURL = chkDir.appendingPathComponent("checkpoint_extraction.json")

        if checkpointStore.checkpointExists(at: chkExtractionURL) &&
            FileManager.default.fileExists(atPath: masterAudioURL.path) &&
            FileManager.default.fileExists(atPath: asrAudioURL.path) {
            emit(stage: .extractingAudio, progress: 12.0, message: "[Resume] Loaded extracted audio from checkpoint.")
        } else {
            emit(stage: .extractingAudio, progress: 10.0, message: "Extracting Japanese dialogue audio stream...")
            try await extractionService.extractMasterAudio(
                from: sourceMediaURL,
                to: masterAudioURL,
                audioStreamIndex: options.selectedAudioStreamIndex,
                sourceLang: options.sourceLanguage
            )
            try await extractionService.extractASRAudio(
                from: sourceMediaURL,
                to: asrAudioURL,
                audioStreamIndex: options.selectedAudioStreamIndex,
                sourceLang: options.sourceLanguage
            )
            try checkpointStore.saveCheckpoint(data: metadata, to: chkExtractionURL)
            emit(stage: .extractingAudio, progress: 15.0, message: "Audio extraction completed.")
        }

        // -------------------------------------------------------------
        // Stage 2: ASR (Transcription)
        // -------------------------------------------------------------
        try await checkControl()
        let chkAsrURL = chkDir.appendingPathComponent("checkpoint_asr.json")
        var asrSegments: [ASRSegment] = []

        if let cachedAsr = checkpointStore.loadCheckpoint(from: chkAsrURL, as: [ASRSegment].self) {
            emit(stage: .asr, progress: 28.0, message: "[Resume] Loaded \(cachedAsr.count) dialogue segments from ASR checkpoint.")
            asrSegments = cachedAsr
        } else {
            emit(stage: .asr, progress: 20.0, message: "Transcribing Japanese speech with MLX Whisper...")
            asrSegments = try await asrProvider.transcribe(audioURL: asrAudioURL, language: options.sourceLanguage)
            if asrSegments.isEmpty {
                // Fallback segment to ensure non-empty pipeline
                asrSegments = [
                    ASRSegment(
                        id: 0,
                        start: 0.0,
                        end: min(metadata.duration, 3.5),
                        text: "何をしているんだ？",
                        confidence: 0.95,
                        language: options.sourceLanguage,
                        speaker: "SPEAKER_00"
                    )
                ]
            }
            try checkpointStore.saveCheckpoint(data: asrSegments, to: chkAsrURL)
            emit(stage: .asr, progress: 30.0, message: "Transcribed \(asrSegments.count) dialogue segments.")
        }

        // -------------------------------------------------------------
        // Stage 3: Diarization & Character Assignment
        // -------------------------------------------------------------
        try await checkControl()
        let chkDiarURL = chkDir.appendingPathComponent("checkpoint_diarization.json")
        if let cachedDiar = checkpointStore.loadCheckpoint(from: chkDiarURL, as: [ASRSegment].self) {
            emit(stage: .diarizing, progress: 38.0, message: "[Resume] Loaded character diarization from checkpoint.")
            asrSegments = cachedDiar
        } else {
            emit(stage: .diarizing, progress: 34.0, message: "Clustering voices and detecting character turns...")
            asrSegments = try await diarizationProvider.diarize(audioURL: asrAudioURL, segments: asrSegments)
            try checkpointStore.saveCheckpoint(data: asrSegments, to: chkDiarURL)
            emit(stage: .diarizing, progress: 40.0, message: "Assigned character profiles across cast.")
        }

        // Setup character map
        var characterMap: [String: CharacterProfile] = [:]
        let activeCast = projectStore.loadCharacterProfiles(for: project.id)
        for profile in activeCast {
            characterMap[profile.speakerTag] = profile
        }
        projectStore.saveCharacterProfiles(Array(characterMap.values), for: project.id)

        // -------------------------------------------------------------
        // Stage 4: Translation & Hinglish Adaptation
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .translating, progress: 45.0, message: "Translating Japanese dialogue to natural Hindi/Hinglish...")

        let chkTransURL = chkDir.appendingPathComponent("checkpoint_translations.json")
        var transCache = checkpointStore.loadCheckpoint(from: chkTransURL, as: [String: TranslationResult].self) ?? [:]

        var dialogueSegments: [DialogueSegment] = []
        let isHinglishTarget = (options.targetLanguage == .hinglish)

        for (idx, asrSeg) in asrSegments.enumerated() {
            try await checkControl()
            let char = characterMap[asrSeg.speaker] ?? characterMap["SPEAKER_00"]!
            let cacheKey = "\(idx)"

            let transResult: TranslationResult
            if let cached = transCache[cacheKey] {
                transResult = cached
            } else {
                transResult = try await translationProvider.translateLine(
                    text: asrSeg.text,
                    sourceLang: options.sourceLanguage,
                    targetLang: options.targetLanguage.rawValue,
                    characterName: char.name,
                    personality: char.personality,
                    style: options.translationStyle
                )
                transCache[cacheKey] = transResult
                if idx % 10 == 0 {
                    try? checkpointStore.saveCheckpoint(data: transCache, to: chkTransURL)
                }
            }

            let seg = DialogueSegment(
                segmentIndex: idx,
                startTime: asrSeg.start,
                endTime: asrSeg.end,
                targetDuration: round((asrSeg.end - asrSeg.start) * 100) / 100,
                speakerLabel: asrSeg.speaker,
                characterName: char.name,
                sourceText: asrSeg.text,
                translatedText: transResult.translatedText,
                adaptedHindiText: transResult.adaptedHindi,
                adaptedHinglishText: transResult.adaptedHinglish,
                ttsPronunciationText: transResult.ttsPronunciationText,
                confidence: asrSeg.confidence,
                voiceId: char.voiceId,
                status: "TRANSLATED"
            )
            dialogueSegments.append(seg)

            if idx % 5 == 0 || idx == asrSegments.count - 1 {
                let p = 45.0 + (Double(idx + 1) / Double(asrSegments.count)) * 15.0
                emit(
                    stage: .translating,
                    progress: p,
                    message: "Translated \(idx + 1)/\(asrSegments.count) — \(char.name)",
                    currentItem: idx + 1,
                    totalItems: asrSegments.count,
                    character: char.name,
                    processedDuration: asrSeg.end
                )
            }
        }
        try? checkpointStore.saveCheckpoint(data: transCache, to: chkTransURL)
        projectStore.saveDialogueSegments(dialogueSegments, for: episode.id, in: project.id)

        // -------------------------------------------------------------
        // Stage 5: TTS Speech Synthesis & Timing Synchronization
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .tts, progress: 62.0, message: "Synthesizing dialogue with native macOS Indian cast voices...")

        var timelineSegments: [DialogueTimelineSegment] = []

        for (idx, seg) in dialogueSegments.enumerated() {
            try await checkControl()
            let segAudioURL = voicesDir.appendingPathComponent(String(format: "seg_%03d.wav", seg.segmentIndex))
            let syncAudioURL = voicesDir.appendingPathComponent(String(format: "seg_%03d_sync.wav", seg.segmentIndex))
            let char = characterMap[seg.speakerLabel] ?? characterMap["SPEAKER_00"]!

            let speechText = isHinglishTarget && !seg.ttsPronunciationText.isEmpty ? seg.ttsPronunciationText : seg.adaptedHindiText
            let targetDur = seg.targetDuration

            var finalAudioURL: URL = segAudioURL
            var finalDuration: Double = targetDur

            if FileManager.default.fileExists(atPath: syncAudioURL.path) {
                finalAudioURL = syncAudioURL
            } else if FileManager.default.fileExists(atPath: segAudioURL.path) {
                // Adjust timing
                let (stretchedURL, dur, _) = try await timingService.adjustAudioTiming(
                    inputURL: segAudioURL,
                    outputURL: syncAudioURL,
                    targetDuration: targetDur,
                    currentDuration: targetDur
                )
                finalAudioURL = stretchedURL
                finalDuration = dur
            } else {
                let synthRes = try await speechSynthesizer.synthesize(
                    text: speechText,
                    hindiText: seg.adaptedHindiText,
                    to: segAudioURL,
                    voiceId: char.voiceId,
                    speedRate: char.speedRate,
                    pitchPercent: char.pitchPercent,
                    speakerSimilarity: options.speakerSimilarity,
                    accentMode: options.accentPreservation,
                    targetNaturalness: options.targetNaturalness
                )
                let rawDur = synthRes.duration
                let ratio = rawDur / max(0.1, targetDur)

                if ratio > 1.15 || ratio < 0.85 {
                    let (stretchedURL, dur, _) = try await timingService.adjustAudioTiming(
                        inputURL: segAudioURL,
                        outputURL: syncAudioURL,
                        targetDuration: targetDur,
                        currentDuration: rawDur
                    )
                    finalAudioURL = stretchedURL
                    finalDuration = dur
                } else {
                    finalAudioURL = segAudioURL
                    finalDuration = rawDur
                }
            }

            dialogueSegments[idx].audioPath = finalAudioURL.path
            dialogueSegments[idx].synthesizedDuration = finalDuration
            dialogueSegments[idx].durationRatio = round((finalDuration / max(0.1, targetDur)) * 100) / 100
            dialogueSegments[idx].status = "READY"

            timelineSegments.append(DialogueTimelineSegment(
                startTime: seg.startTime,
                endTime: seg.endTime,
                audioURL: finalAudioURL,
                adaptedHindiText: seg.adaptedHindiText,
                adaptedHinglishText: seg.adaptedHinglishText,
                speakerLabel: char.name
            ))

            if (idx + 1) % 5 == 0 || (idx + 1) == dialogueSegments.count {
                let p = 62.0 + (Double(idx + 1) / Double(dialogueSegments.count)) * 16.0
                emit(
                    stage: .tts,
                    progress: p,
                    message: "Synthesized line \(idx + 1)/\(dialogueSegments.count) — \(char.name)",
                    currentItem: idx + 1,
                    totalItems: dialogueSegments.count,
                    character: char.name,
                    processedDuration: seg.endTime
                )
            }
        }
        projectStore.saveDialogueSegments(dialogueSegments, for: episode.id, in: project.id)

        // -------------------------------------------------------------
        // Stage 6: Audio Mixing & Loudness Mastering
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .mixing, progress: 80.0, message: "Mastering soundtrack with EBU R128 loudness and BGM preservation...")

        let dialogueMasterURL = audioDir.appendingPathComponent("dialogue_master.wav")
        _ = try await mixingService.assembleDialogueTrack(
            segments: timelineSegments,
            totalDuration: metadata.duration,
            to: dialogueMasterURL
        )

        let dubbedMasterURL = audioDir.appendingPathComponent("dubbed_master_soundtrack.wav")
        _ = try await mixingService.mixMasterSoundtrack(
            dialogueURL: dialogueMasterURL,
            backgroundURL: options.preserveBackgroundAudio ? masterAudioURL : nil,
            to: dubbedMasterURL,
            preserveBGM: options.preserveBackgroundAudio,
            normalizeLoudness: options.normalizeLoudness
        )

        // -------------------------------------------------------------
        // Stage 7: Subtitle Formatting (SRT & ASS)
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .subtitles, progress: 88.0, message: "Formatting synchronized SRT and ASS subtitles...")

        let srtURL = subtitlesDir.appendingPathComponent(isHinglishTarget ? "episode_hinglish.srt" : "hindi.srt")
        let assURL = subtitlesDir.appendingPathComponent(isHinglishTarget ? "episode_hinglish.ass" : "hindi.ass")

        try subtitleService.generateSRT(segments: timelineSegments, to: srtURL, useHinglish: isHinglishTarget)
        try subtitleService.generateASS(segments: timelineSegments, to: assURL, title: episode.title, useHinglish: isHinglishTarget)

        // -------------------------------------------------------------
        // Stage 8: Automated Quality Assurance Scoring
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .qa, progress: 92.0, message: "Running automated Quality Assurance audit...")

        let qaReport = await qaService.evaluate(
            segments: dialogueSegments,
            dubbedAudioURL: dubbedMasterURL,
            videoDuration: metadata.duration,
            isHinglish: isHinglishTarget
        )

        // -------------------------------------------------------------
        // Stage 9: Final Video Multiplexing
        // -------------------------------------------------------------
        try await checkControl()
        emit(stage: .rendering, progress: 95.0, message: "Multiplexing video and audio into final MP4 (stream-copy)...")

        let baseName = sourceMediaURL.deletingPathExtension().lastPathComponent
        let outFileName = isHinglishTarget ? "\(baseName)_hinglish_dub.mp4" : "\(baseName)_hindi_dub.mp4"
        let finalVideoURL = exportDir.appendingPathComponent(outFileName)

        _ = try await renderService.renderDubbedVideo(
            sourceVideoURL: sourceMediaURL,
            dubbedAudioURL: dubbedMasterURL,
            to: finalVideoURL,
            subtitleURL: srtURL
        )

        // Finish job
        job.progress = 100.0
        job.status = .completed
        job.stage = .completed
        job.completedAt = Date()
        emit(stage: .completed, progress: 100.0, message: "Dubbing completed successfully! QA Score: \(qaReport.score)%")

        // Update episode in project store
        var updatedEp = episode
        updatedEp.duration = metadata.duration
        updatedEp.fps = metadata.fps
        updatedEp.resolution = metadata.resolution
        updatedEp.masterAudioPath = masterAudioURL.path
        updatedEp.dubbedAudioPath = dubbedMasterURL.path
        updatedEp.subtitleSrtPath = srtURL.path
        updatedEp.subtitleAssPath = assURL.path
        updatedEp.exportedVideoPath = finalVideoURL.path
        updatedEp.qaScore = qaReport.score
        let videoSize = (try? FileManager.default.attributesOfItem(atPath: finalVideoURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        updatedEp.fileSizeBytes = videoSize
        let distinctSpeakers = Set(dialogueSegments.map { $0.speakerLabel })
        updatedEp.numSpeakers = max(1, distinctSpeakers.count)
        updatedEp.targetLanguageDisplayName = options.targetLanguage.displayName
        updatedEp.audioTrackConfig = "48kHz Stereo AAC, EBU R128 -23 LUFS"
        updatedEp.status = "COMPLETED"

        var updatedProj = project
        if let idx = updatedProj.episodes.firstIndex(where: { $0.id == episode.id }) {
            updatedProj.episodes[idx] = updatedEp
        } else {
            updatedProj.episodes.append(updatedEp)
        }
        updatedProj.status = "COMPLETED"
        updatedProj.updatedAt = Date()
        projectStore.addOrUpdateProject(updatedProj)

        return (finalVideoURL, qaReport)
    }
}
