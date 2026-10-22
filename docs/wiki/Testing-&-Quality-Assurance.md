# Testing & Quality Assurance

This document details the automated testing architecture, test commands, quality gates, and the 5-pillar QA scorecard implemented in Anime Dub Studio.

---

## 1. Automated Test Suite Execution

All tests are implemented using Apple's native Swift Testing framework and execute directly on Apple Silicon macOS:

### Running Fast Core & Integration Test Suites
```bash
swift test --filter "QualityAssuranceTests|SecurityAndResilienceTests|HindiAdaptationTests|HinglishLocalizationTests|DialogueTimingTests|SpeakerSimilarityAndAccentTests|FinishedVideoWorkflowTests|PipelineIntegrationTests|ProviderCapabilitiesAndCacheTests"
```
*Expected Result:* 33 tests in 9 suites passing with 0 failures in under 5 seconds.

### Running Real Full Episode Media Test (23-minute video)
```bash
swift test --filter "FullMetalPanicDubTests"
```
*Expected Result:* Processes 141 dialogue cues from `Full Metal Panic S01E01`, masters EBU R128 soundtrack, formats subtitles, verifies FFprobe stream mapping, and produces final deliverable video in ~278 seconds.

---

## 2. Test Suite Architecture

| Test Suite File | Coverage Scope | Verified Invariants |
| :--- | :--- | :--- |
| `SpeakerSimilarityAndAccentTests.swift` | Formant shaping & presets | Validates distinct audio outputs across 3 accent modes; verifies voice audition preview. |
| `ProviderCapabilitiesAndCacheTests.swift` | Capabilities & Cache | Validates truthful capability disclosures; tests signature-based cache invalidation. |
| `FinishedVideoWorkflowTests.swift` | Results screen & Re-editing | Validates Episode model specifications; verifies Studio timeline preservation on reopen. |
| `SecurityAndResilienceTests.swift` | Process & state safety | Tests pipe deadlock resistance, argument array escaping, and corrupt JSON handling. |
| `QualityAssuranceTests.swift` | Script purity & timing | Detects untranslated Japanese, illegal Devanagari in Hinglish, and excessive English. |
| `HindiAdaptationTests.swift` | Hindi localization | Validates colloquial idiom translation, danda normalization, and duration compression. |
| `HinglishLocalizationTests.swift` | Roman Hinglish | Guarantees zero Devanagari codepoints in Roman output; tests natural loanword mixing. |
| `DialogueTimingTests.swift` | Timestamps & Subtitles | Validates millisecond timestamp formatting for SRT and ASS subtitle files. |
| `PipelineIntegrationTests.swift` | End-to-end pipeline | Runs automated multi-stage pipeline on sample media fixtures. |

---

## 3. The 5-Pillar QA Scorecard

The studio implements an automated quality assurance engine that audits completed dubs:

1. **Dialogue Timing & Sync (Weight: 25%):** Penalizes dialogue whose duration deviates significantly ($> 35\%$) from the original Japanese audio window.
2. **Script Purity & Romanization (Weight: 20%):** Flags unexpected Devanagari characters in Roman Hinglish mode, or untranslated Japanese kanji/kana.
3. **Cast Diversity & Voice Assignment (Weight: 20%):** Fails if multi-speaker dialogue collapses into a single synthesized voice.
4. **Broadcast Loudness Compliance (Weight: 20%):** Verifies that the mastered soundtrack conforms to EBU R128 standards (-23.0 LUFS integrated loudness, $\le -1.0\text{ dB}$ True Peak).
5. **ASR & Translation Confidence (Weight: 15%):** Penalizes segments with low speech recognition confidence score ($< 0.40$).

### Auditioning Advisory
Automated QA validates technical and linguistic compliance. However, it does not substitute for human auditioning of emotional acting, comedic delivery, and dramatic timing.
