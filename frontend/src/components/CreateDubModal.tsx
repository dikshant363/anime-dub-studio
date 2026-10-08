"use client";

import React, { useState, useRef } from "react";
import { Upload, X, ChevronDown, ChevronUp, Sparkles, Volume2, Cpu, Globe, Sliders, AlertTriangle, Film, HardDrive } from "lucide-react";
import {
  isTauriEnvironment,
  pickMediaFile,
  probeMediaFile,
  startDubJob,
  MediaMetadata,
} from "@/lib/tauriBridge";

interface CreateDubModalProps {
  isOpen: boolean;
  onClose: () => void;
  onDubCreated: (data: { jobId: string; episodeId: string; projectId: string }) => void;
}

export default function CreateDubModal({ isOpen, onClose, onDubCreated }: CreateDubModalProps) {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [selectedFilePath, setSelectedFilePath] = useState<string | null>(null);
  const [mediaMetadata, setMediaMetadata] = useState<MediaMetadata | null>(null);
  const [projectName, setProjectName] = useState("");
  const [sourceLang, setSourceLang] = useState("ja");
  const [targetLang, setTargetLang] = useState("hi");
  const [speakerCount, setSpeakerCount] = useState("auto");
  const [showAdvanced, setShowAdvanced] = useState(false);

  // Advanced Options
  const [voiceMode, setVoiceMode] = useState("character_voices");
  const [translationModel, setTranslationModel] = useState("auto");
  const [translationStyle, setTranslationStyle] = useState("natural_anime");
  const [emotionMode, setEmotionMode] = useState("auto");
  const [preserveBackground, setPreserveBackground] = useState(true);
  const [normalizeLoudness, setNormalizeLoudness] = useState(true);
  const [timingMode, setTimingMode] = useState("natural");
  const [worker, setWorker] = useState("auto");

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  const handleNativePick = async () => {
    if (isTauriEnvironment()) {
      const path = await pickMediaFile();
      if (path) {
        setSelectedFilePath(path);
        const name = path.split("/").pop() || "Episode";
        if (!projectName) {
          setProjectName(name.replace(/\.[^/.]+$/, ""));
        }
        const meta = await probeMediaFile(path);
        if (meta) {
          setMediaMetadata(meta);
        }
        return;
      }
    }
    fileInputRef.current?.click();
  };

  const handleFileDrop = (e: React.DragEvent) => {
    e.preventDefault();
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      const file = e.dataTransfer.files[0];
      setSelectedFile(file);
      if (!projectName) {
        setProjectName(file.name.replace(/\.[^/.]+$/, ""));
      }
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setSelectedFile(file);
      if (!projectName) {
        setProjectName(file.name.replace(/\.[^/.]+$/, ""));
      }
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedFile && !selectedFilePath) {
      setError("Please select a video or audio file to dub.");
      return;
    }

    setIsSubmitting(true);
    setError(null);

    // Native macOS Tauri Execution (zero-copy direct on-device processing)
    if (selectedFilePath && isTauriEnvironment()) {
      try {
        const jobId = await startDubJob({
          filePath: selectedFilePath,
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
          translationModel,
          translationStyle,
        });
        onDubCreated({
          jobId,
          episodeId: `native_${jobId}`,
          projectId: `proj_${jobId}`,
        });
        onClose();
        return;
      } catch (err: any) {
        setError(err.message || "Failed to start native dubbing pipeline");
        setIsSubmitting(false);
        return;
      }
    }

    // HTTP Upload Fallback (for browser/FastAPI worker)
    if (selectedFile) {
      const formData = new FormData();
      formData.append("file", selectedFile);
      formData.append(
        "options",
        JSON.stringify({
          project_name: projectName || selectedFile.name,
          source_language: sourceLang,
          target_language: targetLang,
          speaker_count: speakerCount,
          voice_mode: voiceMode,
          translation_model: translationModel,
          translation_style: translationStyle,
          emotion_mode: emotionMode,
          preserve_background: preserveBackground,
          normalize_loudness: normalizeLoudness,
          timing_mode: timingMode,
          worker: worker,
        })
      );

      try {
        const res = await fetch("http://127.0.0.1:8000/api/dub/create", {
          method: "POST",
          body: formData,
        });

        if (!res.ok) {
          const errData = await res.json().catch(() => ({}));
          throw new Error(errData.detail || "Failed to start dubbing job");
        }

        const data = await res.json();
        onDubCreated({
          jobId: data.job_id,
          episodeId: data.episode_id,
          projectId: data.project_id,
        });
        onClose();
      } catch (err: any) {
        setError(err.message || "An unexpected error occurred.");
      } finally {
        setIsSubmitting(false);
      }
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 overflow-y-auto">
      <div className="relative w-full max-w-2xl bg-[#131318] border border-[#23232c] rounded-2xl shadow-2xl p-6 sm:p-8 my-8 text-neutral-100">
        {/* Header */}
        <div className="flex items-center justify-between pb-4 border-b border-[#23232c]">
          <div>
            <h2 className="text-xl font-semibold tracking-tight text-white">Create a dub</h2>
            <p className="text-xs text-neutral-400 mt-0.5">High-fidelity local AI dubbing studio</p>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-neutral-400 hover:text-white rounded-full hover:bg-neutral-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Free dubbing time banner */}
        <div className="my-4 px-4 py-3 bg-[#1c1c24] border border-[#2c2c38] rounded-xl flex items-center justify-between text-xs">
          <span className="text-neutral-300 font-medium">Free dubbing time</span>
          <span className="flex items-center gap-1.5 text-emerald-400 font-medium">
            <span>🎁</span> 30 min free dubbed output
          </span>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-950/40 border border-red-800/60 rounded-xl text-red-200 text-xs">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Tabs */}
          <div className="flex gap-4 border-b border-[#23232c] pb-2 text-sm">
            <button
              type="button"
              className="text-white font-medium border-b-2 border-white pb-2 -mb-2"
            >
              Upload
            </button>
            <button type="button" className="text-neutral-500 hover:text-neutral-300 transition">
              Record
            </button>
          </div>

          {/* Drag & drop upload area */}
          <div
            onDragOver={(e) => e.preventDefault()}
            onDrop={handleFileDrop}
            onClick={handleNativePick}
            className="border-2 border-dashed border-[#2b2b38] hover:border-neutral-500 rounded-2xl p-6 text-center cursor-pointer bg-[#181820]/60 transition group"
          >
            <input
              ref={fileInputRef}
              type="file"
              accept="video/*,audio/*"
              onChange={handleFileChange}
              className="hidden"
            />
            <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-neutral-800/80 flex items-center justify-center text-neutral-300 group-hover:scale-105 transition">
              <Upload className="w-6 h-6" />
            </div>
            {selectedFilePath || selectedFile ? (
              <div className="space-y-2">
                <p className="text-sm font-semibold text-white">
                  {selectedFilePath ? selectedFilePath.split("/").pop() : selectedFile?.name}
                </p>
                {mediaMetadata ? (
                  <div className="inline-flex flex-wrap items-center justify-center gap-2 text-xs text-neutral-400">
                    <span className="px-2 py-0.5 rounded bg-neutral-800 font-mono text-neutral-300">
                      {mediaMetadata.resolution}
                    </span>
                    <span>•</span>
                    <span>{mediaMetadata.duration_secs.toFixed(1)}s</span>
                    <span>•</span>
                    <span>{mediaMetadata.fps.toFixed(0)} fps</span>
                    <span>•</span>
                    <span>{mediaMetadata.file_size_mb.toFixed(1)} MB</span>
                    <span>•</span>
                    <span>{mediaMetadata.audio_channels}ch audio</span>
                  </div>
                ) : (
                  <p className="text-xs text-neutral-400">
                    {selectedFile ? (selectedFile.size / (1024 * 1024)).toFixed(1) + " MB" : ""} • Ready to dub
                  </p>
                )}
                {mediaMetadata && !mediaMetadata.has_enough_disk_space && (
                  <div className="mt-2 text-amber-400 text-xs flex items-center justify-center gap-1">
                    <AlertTriangle className="w-3.5 h-3.5" />
                    Warning: Less than 2 GB disk space available
                  </div>
                )}
              </div>
            ) : (
              <div>
                <p className="text-sm font-medium text-neutral-200">Drag & drop or Click to Select</p>
                <p className="text-xs text-neutral-400 mt-1">
                  Native zero-copy video import • MP4, MKV, MOV, WEBM, WAV
                </p>
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleNativePick();
                  }}
                  className="mt-3 px-4 py-1.5 bg-neutral-800 hover:bg-neutral-700 text-white rounded-lg text-xs font-medium transition"
                >
                  Choose Media File
                </button>
              </div>
            )}
          </div>

          {/* Primary Selectors */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-neutral-300 mb-1.5">
                Source language
              </label>
              <select
                value={sourceLang}
                onChange={(e) => setSourceLang(e.target.value)}
                className="w-full bg-[#181820] border border-[#2b2b38] rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-neutral-400"
              >
                <option value="ja">🇯🇵 Japanese</option>
                <option value="en">🇺🇸 English</option>
                <option value="ko">🇰🇷 Korean</option>
                <option value="zh">🇨🇳 Chinese</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-medium text-neutral-300 mb-1.5">
                Speakers / Characters
              </label>
              <select
                value={speakerCount}
                onChange={(e) => setSpeakerCount(e.target.value)}
                className="w-full bg-[#181820] border border-[#2b2b38] rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-neutral-400"
              >
                <option value="auto">Auto-detect</option>
                <option value="1">1 speaker</option>
                <option value="2">2 speakers</option>
                <option value="3">3 speakers</option>
                <option value="4">4 speakers</option>
                <option value="5+">5+ speakers</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-neutral-300 mb-1.5">
              Target languages
            </label>
            <select
              value={targetLang}
              onChange={(e) => setTargetLang(e.target.value)}
              className="w-full bg-[#181820] border border-[#2b2b38] rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-neutral-400"
            >
              <option value="hi">🇮🇳 Hindi (First-Class Natural Dub)</option>
              <option value="gu">🇮🇳 Gujarati</option>
              <option value="bn">🇧🇩 Bengali</option>
              <option value="mr">🇮🇳 Marathi</option>
              <option value="ta">🇮🇳 Tamil</option>
              <option value="te">🇮🇳 Telugu</option>
              <option value="en">🇺🇸 English</option>
            </select>
          </div>

          {/* Advanced options toggle */}
          <div className="pt-2">
            <button
              type="button"
              onClick={() => setShowAdvanced(!showAdvanced)}
              className="flex items-center justify-between w-full text-xs font-medium text-neutral-400 hover:text-neutral-200 transition py-1"
            >
              <span className="flex items-center gap-1.5">
                <Sliders className="w-3.5 h-3.5" /> Advanced options
              </span>
              {showAdvanced ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
            </button>

            {showAdvanced && (
              <div className="mt-3 p-4 bg-[#181820] border border-[#282834] rounded-xl space-y-4 text-xs">
                <div>
                  <label className="block font-medium text-neutral-300 mb-1">Voice</label>
                  <select
                    value={voiceMode}
                    onChange={(e) => setVoiceMode(e.target.value)}
                    className="w-full bg-[#121216] border border-[#2a2a35] rounded-lg px-3 py-2 text-white"
                  >
                    <option value="character_voices">🎙 Character voices (Hindi Neural Madhur/Swara)</option>
                    <option value="clone_authorized">👤 Authorized voice clone</option>
                    <option value="piper_offline">📦 Offline Piper Neural Voice</option>
                  </select>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block font-medium text-neutral-300 mb-1">Translation model</label>
                    <select
                      value={translationModel}
                      onChange={(e) => setTranslationModel(e.target.value)}
                      className="w-full bg-[#121216] border border-[#2a2a35] rounded-lg px-3 py-2 text-white"
                    >
                      <option value="auto">⚡ Auto (Apple Intelligence / Ollama)</option>
                      <option value="apple_intelligence">🍎 Apple Intelligence (On-device Neural Engine)</option>
                      <option value="ollama">🦙 Ollama — Qwen 3.5 / Gemma</option>
                    </select>
                  </div>
                  <div>
                    <label className="block font-medium text-neutral-300 mb-1">Translation style</label>
                    <select
                      value={translationStyle}
                      onChange={(e) => setTranslationStyle(e.target.value)}
                      className="w-full bg-[#121216] border border-[#2a2a35] rounded-lg px-3 py-2 text-white"
                    >
                      <option value="natural_anime">Natural anime dub</option>
                      <option value="colloquial">Urban colloquial</option>
                      <option value="literal">Literal translation</option>
                      <option value="emotional">High drama / emotional</option>
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block font-medium text-neutral-300 mb-1">Emotion</label>
                    <select
                      value={emotionMode}
                      onChange={(e) => setEmotionMode(e.target.value)}
                      className="w-full bg-[#121216] border border-[#2a2a35] rounded-lg px-3 py-2 text-white"
                    >
                      <option value="auto">Auto-detect from dialogue</option>
                      <option value="neutral">Neutral</option>
                      <option value="excited">Excited / High Energy</option>
                      <option value="angry">Angry / Confrontational</option>
                      <option value="sad">Sad / Emotional</option>
                    </select>
                  </div>
                  <div>
                    <label className="block font-medium text-neutral-300 mb-1">Background audio</label>
                    <select
                      value={preserveBackground ? "preserve" : "mute"}
                      onChange={(e) => setPreserveBackground(e.target.value === "preserve")}
                      className="w-full bg-[#121216] border border-[#2a2a35] rounded-lg px-3 py-2 text-white"
                    >
                      <option value="preserve">Preserve BGM + SFX</option>
                      <option value="mute">Dialogue only (remove background)</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block font-medium text-neutral-300 mb-1">Hardware Worker</label>
                  <select
                    value={worker}
                    onChange={(e) => setWorker(e.target.value)}
                    className="w-full bg-[#121216] border border-[#2a2a35] rounded-lg px-3 py-2 text-white"
                  >
                    <option value="auto">⚡ Auto — M4 Apple Silicon / Colab</option>
                    <option value="mac">💻 Force Local Apple Silicon M4</option>
                    <option value="colab">☁️ Force Google Colab CUDA Worker</option>
                  </select>
                </div>
              </div>
            )}
          </div>

          {/* Action buttons */}
          <div className="flex items-center justify-end gap-3 pt-4 border-t border-[#23232c]">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-5 py-2.5 rounded-xl text-sm font-medium text-neutral-300 hover:text-white hover:bg-neutral-800 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-6 py-2.5 bg-white text-black hover:bg-neutral-200 font-medium rounded-xl text-sm transition shadow-lg disabled:opacity-50 flex items-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin" />
                  Creating dub...
                </>
              ) : (
                "Create dub"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
