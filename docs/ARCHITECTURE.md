# ARCHITECTURE SPECIFICATION — ANIME DUB STUDIO
**Local-First AI Dubbing Workstation for Japanese Anime → Natural Hindi Dubbing**
**Version:** 1.0.0
**Target Platforms:** Apple Silicon (M4 / macOS 26+) & Google Colab (CUDA / Linux)

---

## 1. System Philosophy & Non-Negotiables

Anime Dub Studio is an on-device, local-first studio for voice dubbing and localization, engineered around four core tenets:

1. **Deterministic Safety Boundaries:** Probabilistic AI models (LLMs, neural ASR, diffusion/neural TTS) are strictly wrapped in deterministic schema validators, timing boundary enforcers, and transactional state machines.
2. **Hardware-Aware Execution:** Built natively for Apple Silicon M4 unified memory architecture (using MLX, Metal, and Apple Foundation Models) while providing transparent offloading to Google Colab CUDA workers when higher batch VRAM or distributed rendering is desired.
3. **Natural Hindi Localization Over Literal Translation:** Translation is treated as a multi-stage adaptation process: capturing nuance, honorifics, and character personality, followed by timing-constrained colloquial Hindi dialogue synthesis.
4. **Resilience & Checkpoint Immutability:** Every processing stage emits immutable intermediate artifacts. If a downstream stage fails or is manually edited by the user, prior stages are never recomputed unnecessarily.

```
                     Anime Dub Studio Workspace
                                 │
                   Next.js 15+ Frontend (React, Tailwind)
                                 │
                     FastAPI REST & WebSocket API
                                 │
                     Job Scheduler & State Machine
                                 │
              ┌──────────────────┴──────────────────┐
              │                                     │
      Local M4 Worker                        Colab Worker
    (MLX, Metal, Ollama)                    (CUDA, PyTorch)
              │                                     │
              └──────────────────┬──────────────────┘
                                 │
                         DUBBING PIPELINE
                                 │
   ┌──────────────┬──────────────┼──────────────┬──────────────┐
   ▼              ▼              ▼              ▼              ▼
Ingestion   Separation         ASR         Diarization    Translation
 (FFmpeg)   (Demucs-MLX)   (MLX-Whisper)  (PyAnnote/VAD)  (Ollama/Apple)
                                                               │
                                                               ▼
                                                       Hindi Adaptation
                                                               │
                                                               ▼
                                                       Character Voices
                                                         (Edge/Piper)
                                                               │
                                                               ▼
                                                         Timing Sync
                                                         (WSOLA/atempo)
                                                               │
                                                               ▼
                                                       Mixer & Ducking
                                                       (Loudnorm EBU)
                                                               │
                                                               ▼
                                                       Automated QA
                                                               │
                                                               ▼
                                                         Render & Mux
                                                       (Final Dub MP4)
```

---

## 2. Hardware Abstraction Layer (HAL)

The application defines clean abstract base classes (`ABC`) to isolate hardware-dependent model runtimes. The backend runtime resolves implementations through the `HardwareWorker` router:

### 2.1 Transcriber Interface
```python
class Transcriber(ABC):
    @abstractmethod
    async def transcribe(
        self, audio_path: Path, language: str = "ja"
    ) -> List[TranscriptionSegment]:
        """Returns ordered segments with start, end, text, and confidence."""
        pass
```
* **Implementations:**
  - `MLXWhisperTranscriber`: Targets Apple Silicon GPU/NE via `mlx-whisper`.
  - `WhisperXTranscriber`: Targets NVIDIA CUDA on Google Colab with batched phoneme alignment.
  - `FasterWhisperTranscriber`: Universal CPU/CUDA fallback via CTranslate2.

### 2.2 AudioSeparator Interface
```python
class AudioSeparator(ABC):
    @abstractmethod
    async def separate(
        self, audio_path: Path, output_dir: Path
    ) -> AudioSeparationResult:
        """Separates audio into vocals and background (music + sfx) stems."""
        pass
```
* **Implementations:**
  - `DemucsMLXSeparator`: Fast Metal-accelerated 2-stem separation on M4.
  - `TorchDemucsSeparator`: PyTorch CUDA Demucs on Colab.
  - `FFmpegSpectralSeparator`: Zero-RAM spectral ducking fallback for low-memory constraints.

### 2.3 Translation & Hindi Adaptation Interface
```python
class TranslationEngine(ABC):
    @abstractmethod
    async def translate_and_adapt(
        self,
        segments: List[DialogueSegment],
        character_profiles: Dict[str, CharacterProfile],
        source_lang: str = "ja",
        target_lang: str = "hi",
        style: TranslationStyle = TranslationStyle.NATURAL_ANIME,
    ) -> List[AdaptedSegment]:
        """Translates and adapts dialogue with context and syllable constraints."""
        pass
```
* **Implementations:**
  - `OllamaTranslationEngine`: Local Ollama REST client running `qwen3.5:4b` or `gemma4:e2b`.
  - `AppleIntelligenceEngine`: Swift bridge invoking macOS 26+ `FoundationModels.SystemLanguageModel`.
  - `ArgosTranslationEngine`: 100% offline OpenNMT translation fallback.

### 2.4 Text-to-Speech (TTS) Interface
```python
class TTSProvider(ABC):
    @abstractmethod
    async def synthesize(
        self,
        text: str,
        character: CharacterProfile,
        emotion: str,
        target_duration: Optional[float] = None,
        output_path: Path = None,
    ) -> TTSResult:
        """Synthesizes speech matching character voice, pitch, and emotion."""
        pass
```
* **Implementations:**
  - `EdgeTTSProvider`: High-naturalness studio Hindi neural voices (`hi-IN-SwaraNeural`, `hi-IN-MadhurNeural`).
  - `PiperTTSProvider`: Fast offline ONNX Hindi voices (`hi_IN-rohan-medium`, `hi_IN-pratham-medium`).
  - `QwenTTSProvider`: Multilingual 0.6B/1.7B voice-cloned model with emotion prompting.

---

## 3. Data Flow & Pipeline Stages

### Stage 1: Ingestion & Stream Analysis
* Inspects media via `ffprobe` (codecs, FPS, audio channels, sample rates).
* Extracts master audio stream as uncompressed PCM WAV (16kHz / 24kHz 16-bit mono for ASR/Diarization; 48kHz 24-bit stereo for master mix).
* **Zero unnecessary video transcoding:** Original video bitstream is preserved intact for final multiplexing.

### Stage 2: Audio Source Separation
* Audio is split into:
  1. `vocals.wav` (Clean dialogue for transcription & diarization)
  2. `background.wav` (Instrumental BGM, Foley, ambience, sound effects)
* Clean vocals are fed to ASR, preventing background anime battle music from hallucinating fake subtitles.

### Stage 3: ASR & Word Alignment
* Transcribes Japanese dialogue into structured JSON segments.
* Calculates segment-level and word-level start/end timestamps.
* Flags low-confidence segments (`confidence < 0.60`) for human review.

### Stage 4: Speaker Diarization & Character Mapping
* Identifies distinct speaker clusters (`SPEAKER_00`, `SPEAKER_01`, etc.).
* Allows automated or user-guided mapping to `CharacterProfile` records:
  - Gender / Presentation
  - Target Hindi Voice ID
  - Pitch & Speed modifiers
  - Personality traits (e.g., "shonen protagonist, high energy, loud")

### Stage 5: Context-Aware Translation & Natural Hindi Adaptation
* Multi-stage prompt pipeline:
  1. **Pass 1: Cultural Translation:** Translates Japanese dialogue maintaining anime honorifics (-san, -kun, -sensei) and narrative continuity across adjacent lines.
  2. **Pass 2: Hindi Dub Localization:** Converts stiff or bookish translations into natural Hindi anime dubbing vernacular (e.g., standard Indian anime localization conventions).
  3. **Pass 3: Syllable / Duration Fitting:** Analyzes available time slot ($T_{target} = T_{end} - T_{start}$) and compresses Devanagari phrasing if estimated syllable duration exceeds the window.

### Stage 6: Character Voice Synthesis & Emotion Conditioning
* Dispatches adapted Hindi lines to the selected `TTSProvider`.
* Injects emotion tags (`happy`, `angry`, `whisper`, `excited`, `sad`) and character-specific pitch/speed offsets.
* Generates segment WAV files in the episode's voices directory.

### Stage 7: Timing Engine & Audio Time-Stretching
* Measures actual synthesized audio duration ($D_{synth}$) against original segment window ($D_{target}$).
* Computes duration ratio $R = D_{synth} / D_{target}$:
  - If $0.90 \le R \le 1.10$: Use as-is, natural pacing.
  - If $0.75 \le R < 0.90$ or $1.10 < R \le 1.25$: Apply high-quality WSOLA time-stretching (`atempo` filter in FFmpeg) without altering pitch.
  - If $R > 1.25$: Trigger automated LLM text shortening loop before falling back to maximum 1.25x stretch.

### Stage 8: Sound Design Mixing, Ducking & Normalization
* Aligns dubbed Hindi speech segments into a continuous dialogue track.
* Applies dynamic sidechain ducking to the `background.wav` stem:
  - When Hindi dialogue is active, background audio is gently attenuated by -6 dB to -10 dB with a 150ms smooth release.
* Combines dubbed dialogue + ducked background stems.
* Applies EBU R128 loudness normalization (`loudnorm` filter: Integrated Loudness -23 LUFS, True Peak -1.0 dBFS).

### Stage 9: Automated Quality Assurance (QA) Engine
* Validates generated assets against automated sanity rules:
  - Missing audio segments / 0-byte files
  - Audio clipping or severe peak distortion
  - Unadapted or untranslated characters (residual Kanji/Katakana in Hindi output)
  - Timing drift (>0.3s desynchronization)
  - Subtitle alignment discrepancies
* Assigns an automated studio readiness score (0-100) and displays detailed warnings in the Dubbing Editor.

### Stage 10: Subtitle Generation & Final Multiplexing
* Generates stylized Devanagari Hindi subtitles (`.srt` and `.ass` formats).
* Muxes original video bitstream + dubbed normalized stereo audio track + subtitle streams into final MP4 using `-c:v copy -c:a aac -b:a 256k`.

---

## 4. Storage & Directory Hierarchy

Anime Dub Studio adheres to a transparent, inspectable file-based project hierarchy backed by a lightweight SQLite database for search and metadata:

```text
storage/
  projects/
    {project_id}/
      project.json
      characters/
        characters.json
        voice_samples/
      episodes/
        {episode_id}/
          episode.json
          source/
            original_media.mp4
            metadata.json
          audio/
            master_audio.wav
          separation/
            vocals.wav
            background.wav
          transcription/
            asr_raw.json
            segments.json
          diarization/
            speakers.json
          translation/
            draft_translation.json
            adapted_hindi.json
          voices/
            seg_001.wav
            seg_002.wav
            ...
          timing/
            aligned_timeline.json
          subtitles/
            hindi.srt
            hindi.ass
          qa/
            qa_report.json
          export/
            dubbed_output.mp4
```

---

## 5. UI Architecture & Studio Workflows

### 5.1 Focused "Create a Dub" Modal
Following the reference UX design:
* **Drag & Drop Media Ingestion:** Video/audio upload with format inspection.
* **Language Selection:** Source Language (🇯🇵 Japanese default) → Target Language (🇮🇳 Hindi default).
* **Speaker Count:** Auto-detect or explicit character count selection (1, 2, 3, 4, 5+).
* **Progressive Disclosure (Advanced Options):**
  - Voice selection (Character voices / Piper / Authorized clone)
  - Translation Model (Ollama Qwen 3.5 / Apple Intelligence / Argos)
  - Translation Style (Natural anime dub / Colloquial / Literal)
  - Audio Features (Preserve BGM/SFX, Loudness normalization)
  - Worker Selection (⚡ Auto — M4 / Colab)
* **Single Click Action:** [Create dub]

### 5.2 Real-Time Job Monitor
* Step-by-step progress tracking with real-time logs via WebSockets.
* Ability to leave the page or restart individual stages.

### 5.3 Multi-Track Dubbing Editor
* Video preview player synchronized with timeline.
* Dialogue segment card view showing:
  - Japanese source text
  - Natural Hindi translation
  - Character and Voice assignment
  - Emotion selector
  - Speed / Pitch controls
  - One-click [▶ Preview], [Regenerate Voice], [Re-adapt Text]
* Real-time QA warning badges.
* One-click [Export Final Dub].

---

## 6. Security, Legal Boundaries & Privacy

1. **Local-First Zero-Telemetry:** All media stays strictly on the user's workstation or their self-hosted Google Colab instance.
2. **Authorized Voice Cloning Only:** Voice cloning APIs reject arbitrary web scrapers; reference samples must be user-provided with clear authorization acknowledgments in the UI.
3. **No DRM Circumvention:** The application strictly processes local, legally obtained media files.
