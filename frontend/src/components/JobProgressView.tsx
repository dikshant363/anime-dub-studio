"use client";

import React, { useEffect, useState, useRef } from "react";
import {
  CheckCircle2,
  Circle,
  Loader2,
  AlertCircle,
  ArrowRight,
  Pause,
  Play,
  XCircle,
  Terminal,
  ChevronDown,
  ChevronUp,
  Clock,
  Gauge,
  Film,
  User,
} from "lucide-react";
import {
  isTauriEnvironment,
  getJobStatus,
  notifyUser,
  cancelDubJob,
  pauseDubJob,
  resumeDubJob,
  JobProgress,
} from "@/lib/tauriBridge";

interface JobProgressViewProps {
  jobId: string;
  episodeId: string;
  onFinished: (episodeId: string) => void;
  onBackToDashboard: () => void;
}

const PIPELINE_STAGES = [
  { key: "EXTRACTING_AUDIO", label: "Audio Extraction" },
  { key: "ASR", label: "Whisper ASR" },
  { key: "DIARIZING", label: "Diarization & Character Assignment" },
  { key: "TRANSLATING", label: "Semantic Translation" },
  { key: "HINGLISH", label: "Hinglish Adaptation" },
  { key: "TTS", label: "Character Voice Synthesis" },
  { key: "TIMING", label: "Dialogue Timing Alignment" },
  { key: "MIXING", label: "BGM/SFX Audio Preservation" },
  { key: "RENDERING", label: "Lossless Remux & Subtitle Generation" },
  { key: "QA", label: "Quality Assurance Validation" },
];

function formatDuration(seconds?: number): string {
  if (seconds === undefined || seconds === null || isNaN(seconds)) return "--:--";
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const remS = s % 60;
  return `${m.toString().padStart(2, "0")}:${remS.toString().padStart(2, "0")}`;
}

export default function JobProgressView({
  jobId,
  episodeId,
  onFinished,
  onBackToDashboard,
}: JobProgressViewProps) {
  const [job, setJob] = useState<JobProgress | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPaused, setIsPaused] = useState(false);
  const [isCancelled, setIsCancelled] = useState(false);
  const [isActionLoading, setIsActionLoading] = useState(false);
  const [showLogs, setShowLogs] = useState(true);
  const logsEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let interval: NodeJS.Timeout;

    const pollJob = async () => {
      if (isCancelled) return;
      try {
        let data: JobProgress | null = null;
        if (isTauriEnvironment()) {
          data = await getJobStatus(jobId);
        } else {
          const res = await fetch(`http://127.0.0.1:8000/api/jobs/${jobId}`);
          if (!res.ok) throw new Error("Could not fetch job status");
          data = await res.json();
        }

        if (data) {
          setJob(data);

          if (data.status === "PAUSED") {
            setIsPaused(true);
          } else if (data.status === "RUNNING") {
            setIsPaused(false);
          }

          if (data.status === "COMPLETED") {
            clearInterval(interval);
            notifyUser(
              "Anime Dubbing Complete",
              "Hindi anime dubbing pipeline completed with QA check passed!"
            );
            onFinished(episodeId);
          } else if (data.status === "FAILED") {
            clearInterval(interval);
            setError(data.message || "Dubbing pipeline failed.");
          } else if (data.status === "CANCELLED") {
            clearInterval(interval);
            setIsCancelled(true);
          }
        }
      } catch (err: any) {
        console.warn("Poll job error:", err);
      }
    };

    pollJob();
    interval = setInterval(pollJob, 1000);

    return () => clearInterval(interval);
  }, [jobId, episodeId, onFinished, isCancelled]);

  useEffect(() => {
    if (showLogs) {
      logsEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [job?.logs, showLogs]);

  const handlePause = async () => {
    setIsActionLoading(true);
    try {
      await pauseDubJob(jobId);
      setIsPaused(true);
    } catch (e) {
      console.error(e);
    } finally {
      setIsActionLoading(false);
    }
  };

  const handleResume = async () => {
    setIsActionLoading(true);
    try {
      await resumeDubJob(jobId);
      setIsPaused(false);
    } catch (e) {
      console.error(e);
    } finally {
      setIsActionLoading(false);
    }
  };

  const handleCancel = async () => {
    if (
      window.confirm(
        "Are you sure you want to cancel this dubbing job? All completed checkpoint stages will be safely preserved on disk."
      )
    ) {
      setIsActionLoading(true);
      try {
        await cancelDubJob(jobId);
        setIsCancelled(true);
      } catch (e) {
        console.error(e);
      } finally {
        setIsActionLoading(false);
      }
    }
  };

  const currentStageKey = job?.stage || "PREPARING";
  const completedStages = job?.completed_stages || [];
  const progress = Math.min(100.0, Math.max(0.0, job?.progress || 0.0));
  const currentStageLabel = job?.stage_label || "Initial Preparation";

  return (
    <div className="max-w-3xl mx-auto py-10 px-4 sm:px-6">
      <div className="bg-[#121217] border border-[#23232c] rounded-2xl p-6 sm:p-8 shadow-2xl space-y-6">
        {/* Header Wireframe: Dubbing Title & Active Stage */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-5 border-b border-[#23232c] gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Film className="w-4 h-4 text-neutral-400" />
              <h2 className="text-lg font-bold text-white tracking-tight">
                Dubbing: {job?.project_title || job?.source_filename || "Anime Dub"}
              </h2>
            </div>
            <div className="flex flex-wrap items-center gap-3 mt-1.5 text-xs">
              <span className="flex items-center gap-1.5 text-neutral-400">
                <span>Stage:</span>
                <span className="font-semibold text-white px-2 py-0.5 rounded bg-neutral-800 border border-neutral-700">
                  {currentStageLabel}
                </span>
              </span>
              <span className="text-neutral-600">•</span>
              <span className="text-neutral-400 font-mono text-[11px]">
                Engine: <span className="text-neutral-200">{job?.voice_provider || "Local Apple Silicon (macOS Speech)"}</span>
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            <span
              className={`px-2.5 py-1 rounded-full text-xs font-mono font-medium flex items-center gap-1.5 ${
                job?.status === "COMPLETED"
                  ? "bg-emerald-950/80 text-emerald-300 border border-emerald-800"
                  : job?.status === "FAILED"
                  ? "bg-red-950/80 text-red-300 border border-red-800"
                  : isCancelled || job?.status === "CANCELLED"
                  ? "bg-neutral-800 text-neutral-400 border border-neutral-700"
                  : isPaused || job?.status === "PAUSED"
                  ? "bg-amber-950/80 text-amber-300 border border-amber-800"
                  : "bg-emerald-950/50 text-emerald-400 border border-emerald-800/60"
              }`}
            >
              {job?.status === "COMPLETED" ? (
                "✓ Completed"
              ) : job?.status === "FAILED" ? (
                "✕ Stopped"
              ) : isCancelled ? (
                "✕ Cancelled"
              ) : isPaused ? (
                "❚❚ Paused"
              ) : (
                <>
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                  Live Processing
                </>
              )}
            </span>
            <button
              onClick={onBackToDashboard}
              className="text-xs text-neutral-400 hover:text-white px-3 py-1 rounded-lg bg-neutral-800/80 hover:bg-neutral-800 transition"
            >
              Dashboard
            </button>
          </div>
        </div>

        {/* Progress Bar & Percentage */}
        <div className="space-y-2">
          <div className="flex justify-between items-center text-xs">
            <span className="text-neutral-400 font-mono">Weighted Pipeline Progress</span>
            <span className="text-white font-mono font-bold text-sm">{progress.toFixed(0)}%</span>
          </div>
          <div className="w-full h-3 bg-[#1c1c24] border border-[#2a2a38] rounded-full overflow-hidden p-0.5">
            <div
              className={`h-full rounded-full transition-all duration-300 ease-out ${
                job?.status === "FAILED"
                  ? "bg-red-500"
                  : isPaused
                  ? "bg-amber-400"
                  : isCancelled
                  ? "bg-neutral-600"
                  : "bg-white"
              }`}
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>

        {/* Real-time Metrics Card */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 bg-[#171720] border border-[#262634] rounded-xl text-xs">
          {/* Processed vs Source Duration */}
          <div className="space-y-1">
            <span className="text-neutral-400 text-[11px] block">Processed Media Timeline</span>
            <span className="font-mono text-white font-semibold text-sm">
              {job?.processed_time_str || "00:00"} / {job?.source_duration_str || "22:49"}
            </span>
          </div>

          {/* Current Character & Segment */}
          <div className="space-y-1">
            <span className="text-neutral-400 text-[11px] block">Current Dialogue</span>
            <div className="font-mono text-white font-semibold flex items-center gap-1.5 truncate">
              <User className="w-3.5 h-3.5 text-neutral-400 flex-shrink-0" />
              <span className="text-emerald-300 truncate">
                {job?.current_character || "Master Cast"}
              </span>
              {job?.total_items ? (
                <span className="text-neutral-400 text-[11px]">
                  ({job?.current_item || 0} / {job?.total_items})
                </span>
              ) : null}
            </div>
          </div>

          {/* Performance: Elapsed, Remaining, Speed */}
          <div className="space-y-1">
            <span className="text-neutral-400 text-[11px] block">Performance & ETA</span>
            <div className="flex items-center gap-3 text-neutral-300 font-mono text-[11px]">
              <span title="Elapsed Time">
                ⏱ {formatDuration(job?.elapsed_seconds)}
              </span>
              <span>•</span>
              <span title="Estimated Remaining">
                ~{formatDuration(job?.estimated_remaining_seconds)}
              </span>
              <span>•</span>
              <span className="text-white font-semibold" title="Processing Speed">
                ⚡ {(job?.speed_x || 1.0).toFixed(1)}x
              </span>
            </div>
          </div>
        </div>

        {/* Part 28 Structured Error Recovery Card */}
        {job?.status === "FAILED" && (
          <div className="p-5 bg-red-950/40 border border-red-800/80 rounded-2xl space-y-4 shadow-xl">
            <div className="flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
              <div className="space-y-1">
                <h3 className="text-sm font-bold text-red-200">
                  Dubbing stopped at {job?.stage_label || currentStageLabel} ({progress.toFixed(0)}%{job?.total_items ? `, ${job?.current_item || 0}/${job?.total_items}` : ""})
                </h3>
                <p className="text-xs text-red-300 font-mono leading-relaxed">
                  {job?.message || error || "An unexpected error occurred during pipeline execution."}
                </p>
                {job?.error_detail && (
                  <div className="mt-2 p-2.5 bg-black/60 border border-red-900/60 rounded-lg text-[11px] font-mono text-red-300 max-h-28 overflow-y-auto whitespace-pre-wrap">
                    {job.error_detail}
                  </div>
                )}
              </div>
            </div>

            {/* Checkpoint Preservation Info */}
            <div className="p-3 bg-black/40 border border-red-900/50 rounded-xl text-xs space-y-1.5">
              <div className="flex items-center gap-2 text-neutral-300 font-medium">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                <span>Checkpoints Preserved: Earlier stages are safely saved on disk.</span>
              </div>
              <p className="text-[11px] text-neutral-400 leading-normal">
                {job?.recovery_action || "Audio extraction, ASR transcription, and completed dialogue assets are cached. Retrying will resume without recomputing prior stages."}
              </p>
            </div>

            {/* Error Actions */}
            <div className="flex flex-wrap items-center gap-2.5 pt-1">
              <button
                type="button"
                onClick={() => {
                  window.location.reload();
                }}
                className="px-4 py-2 bg-red-600 hover:bg-red-500 text-white rounded-xl text-xs font-semibold transition flex items-center gap-1.5 shadow"
              >
                Retry from checkpoint
              </button>

              <button
                type="button"
                onClick={() => setShowLogs(true)}
                className="px-4 py-2 bg-neutral-800 hover:bg-neutral-700 text-neutral-200 rounded-xl text-xs font-medium transition flex items-center gap-1.5 border border-neutral-700"
              >
                <Terminal className="w-3.5 h-3.5" /> View Logs
              </button>

              <button
                type="button"
                onClick={onBackToDashboard}
                className="px-4 py-2 bg-neutral-900 hover:bg-neutral-800 text-neutral-400 hover:text-white rounded-xl text-xs font-medium transition"
              >
                Back to Dashboard
              </button>
            </div>
          </div>
        )}

        {/* Stages Checklist */}
        <div className="space-y-2.5">
          <h3 className="text-xs font-semibold text-neutral-400 uppercase tracking-wider">
            Pipeline Stages
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
            {PIPELINE_STAGES.map((st) => {
              const isCompleted =
                completedStages.includes(st.key) || job?.status === "COMPLETED";
              const isCurrent = currentStageKey === st.key;
              const isFailedStage = isCurrent && job?.status === "FAILED";
              const isActive = isCurrent && job?.status !== "COMPLETED" && job?.status !== "FAILED";

              return (
                <div
                  key={st.key}
                  className={`flex items-center gap-2.5 p-2 rounded-lg border transition ${
                    isCompleted
                      ? "bg-[#141d17] border-[#22442d] text-neutral-200"
                      : isFailedStage
                      ? "bg-red-950/30 border-red-800/60 text-red-300 font-medium"
                      : isActive
                      ? "bg-[#1c1c28] border-neutral-400 text-white font-medium"
                      : "bg-[#131318] border-[#202028] text-neutral-500"
                  }`}
                >
                  {isCompleted ? (
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                  ) : isFailedStage ? (
                    <AlertCircle className="w-4 h-4 text-red-400 flex-shrink-0" />
                  ) : isActive ? (
                    <Loader2 className="w-4 h-4 text-white animate-spin flex-shrink-0" />
                  ) : (
                    <Circle className="w-4 h-4 text-neutral-600 flex-shrink-0" />
                  )}
                  <span className="truncate">{st.label}</span>
                  {isActive && (
                    <span className="ml-auto text-[10px] text-emerald-400 font-mono">
                      in progress
                    </span>
                  )}
                  {isFailedStage && (
                    <span className="ml-auto text-[10px] text-red-400 font-mono">
                      stopped
                    </span>
                  )}
                  {isCompleted && (
                    <span className="ml-auto text-[10px] text-neutral-500 font-mono">
                      done
                    </span>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* Process Control Buttons */}
        <div className="flex flex-wrap items-center justify-between pt-4 border-t border-[#23232c] gap-3">
          <div className="flex items-center gap-2">
            {!isPaused ? (
              <button
                type="button"
                onClick={handlePause}
                disabled={isActionLoading || isCancelled || job?.status === "COMPLETED"}
                className="px-4 py-2 bg-neutral-800 hover:bg-neutral-700 disabled:opacity-40 text-neutral-200 hover:text-white rounded-xl text-xs font-medium transition flex items-center gap-1.5"
              >
                <Pause className="w-3.5 h-3.5" /> Pause
              </button>
            ) : (
              <button
                type="button"
                onClick={handleResume}
                disabled={isActionLoading || isCancelled || job?.status === "COMPLETED"}
                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white rounded-xl text-xs font-medium transition flex items-center gap-1.5"
              >
                <Play className="w-3.5 h-3.5" /> Resume
              </button>
            )}

            <button
              type="button"
              onClick={handleCancel}
              disabled={isActionLoading || isCancelled || job?.status === "COMPLETED"}
              className="px-4 py-2 bg-red-950/60 hover:bg-red-900 border border-red-800/60 disabled:opacity-40 text-red-200 rounded-xl text-xs font-medium transition flex items-center gap-1.5"
            >
              <XCircle className="w-3.5 h-3.5" /> Cancel Job
            </button>
          </div>

          {job?.status === "COMPLETED" && (
            <button
              onClick={() => onFinished(episodeId)}
              className="px-5 py-2.5 bg-white text-black hover:bg-neutral-200 rounded-xl text-sm font-semibold transition flex items-center gap-2 shadow-lg"
            >
              Open Dubbing Studio <ArrowRight className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Live Terminal Logs Drawer */}
        <div className="pt-2">
          <button
            type="button"
            onClick={() => setShowLogs(!showLogs)}
            className="flex items-center justify-between w-full text-xs text-neutral-400 hover:text-neutral-200 py-1"
          >
            <span className="flex items-center gap-1.5 font-mono">
              <Terminal className="w-3.5 h-3.5 text-neutral-500" /> Live Orchestrator Events
            </span>
            {showLogs ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
          </button>

          {showLogs && (
            <div className="mt-2 p-3 bg-black/80 border border-[#23232c] rounded-xl font-mono text-[11px] text-neutral-400 max-h-36 overflow-y-auto space-y-1">
              {job?.logs && job.logs.length > 0 ? (
                job.logs.map((log: any, idx: number) => (
                  <div key={idx} className="flex items-start gap-2 leading-relaxed">
                    <span className="text-neutral-600 select-none">&gt;</span>
                    <span className="text-neutral-300">
                      {typeof log === "string" ? log : log.message || JSON.stringify(log)}
                    </span>
                  </div>
                ))
              ) : (
                <div className="text-neutral-600">Waiting for engine events...</div>
              )}
              <div ref={logsEndRef} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
