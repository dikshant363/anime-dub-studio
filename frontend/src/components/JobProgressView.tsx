"use client";

import React, { useEffect, useState } from "react";
import { CheckCircle2, Circle, Loader2, AlertCircle, ArrowRight } from "lucide-react";

interface JobProgressViewProps {
  jobId: string;
  episodeId: string;
  onFinished: (episodeId: string) => void;
  onBackToDashboard: () => void;
}

const STAGES = [
  { key: "UPLOADING", label: "Upload complete" },
  { key: "EXTRACTING_AUDIO", label: "Audio extracted" },
  { key: "ASR", label: "Japanese transcription complete" },
  { key: "DIARIZING", label: "Speakers & characters detected" },
  { key: "TRANSLATING", label: "Hindi translation complete" },
  { key: "TTS", label: "Generating character voices" },
  { key: "TIMING", label: "Synchronizing dialogue timing" },
  { key: "MIXING", label: "Mixing BGM + SFX" },
  { key: "QA", label: "Quality assurance check" },
  { key: "RENDERING", label: "Rendering final video" },
];

export default function JobProgressView({
  jobId,
  episodeId,
  onFinished,
  onBackToDashboard,
}: JobProgressViewProps) {
  const [job, setJob] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let interval: NodeJS.Timeout;

    const pollJob = async () => {
      try {
        const res = await fetch(`http://127.0.0.1:8000/api/jobs/${jobId}`);
        if (!res.ok) throw new Error("Could not fetch job status");
        const data = await res.json();
        setJob(data);

        if (data.status === "COMPLETED") {
          clearInterval(interval);
          onFinished(episodeId);
        } else if (data.status === "FAILED") {
          clearInterval(interval);
          setError(data.error_message || "Dubbing pipeline failed.");
        }
      } catch (err: any) {
        setError(err.message);
      }
    };

    pollJob();
    interval = setInterval(pollJob, 1500);

    return () => clearInterval(interval);
  }, [jobId, episodeId, onFinished]);

  const currentStageIndex = STAGES.findIndex((s) => s.key === job?.stage);
  const progress = job?.progress || 10.0;

  return (
    <div className="max-w-2xl mx-auto py-12 px-4 sm:px-6">
      <div className="bg-[#131318] border border-[#23232c] rounded-2xl p-6 sm:p-8 shadow-2xl">
        <div className="flex items-center justify-between pb-6 border-b border-[#23232c]">
          <div>
            <h2 className="text-xl font-semibold text-white">Creating your dub...</h2>
            <p className="text-xs text-neutral-400 mt-1">
              Worker: <span className="text-white font-medium">Apple Silicon M4 (Local)</span> • Neural Engine active
            </p>
          </div>
          <button
            onClick={onBackToDashboard}
            className="text-xs text-neutral-400 hover:text-white px-3 py-1.5 rounded-lg bg-neutral-800 transition"
          >
            Leave in background
          </button>
        </div>

        {/* Overall progress bar */}
        <div className="my-6">
          <div className="flex justify-between text-xs text-neutral-400 mb-2">
            <span>Overall Studio Progress</span>
            <span className="text-white font-medium">{progress.toFixed(0)}%</span>
          </div>
          <div className="w-full h-2 bg-neutral-800 rounded-full overflow-hidden">
            <div
              className="h-full bg-white transition-all duration-500 ease-out rounded-full"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-950/40 border border-red-800/60 rounded-xl flex items-center gap-3 text-red-200 text-xs">
            <AlertCircle className="w-5 h-5 flex-shrink-0" />
            <div>
              <p className="font-semibold">Pipeline Error</p>
              <p className="mt-0.5">{error}</p>
            </div>
          </div>
        )}

        {/* Stage Checklist */}
        <div className="space-y-3.5 my-6">
          {STAGES.map((stage, idx) => {
            const isCompleted = currentStageIndex > idx || job?.status === "COMPLETED";
            const isCurrent = currentStageIndex === idx && job?.status !== "COMPLETED";

            return (
              <div
                key={stage.key}
                className={`flex items-center gap-3 text-sm transition ${
                  isCompleted
                    ? "text-neutral-200 font-medium"
                    : isCurrent
                    ? "text-white font-semibold"
                    : "text-neutral-500"
                }`}
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                ) : isCurrent ? (
                  <Loader2 className="w-4 h-4 text-white animate-spin flex-shrink-0" />
                ) : (
                  <Circle className="w-4 h-4 text-neutral-600 flex-shrink-0" />
                )}
                <span>{stage.label}</span>
                {isCurrent && (
                  <span className="ml-auto text-xs font-mono text-neutral-400">
                    in progress...
                  </span>
                )}
              </div>
            );
          })}
        </div>

        {job?.status === "COMPLETED" && (
          <div className="pt-4 border-t border-[#23232c] flex justify-end">
            <button
              onClick={() => onFinished(episodeId)}
              className="px-5 py-2.5 bg-white text-black hover:bg-neutral-200 rounded-xl text-sm font-medium transition flex items-center gap-2 shadow-lg"
            >
              Open Dubbing Editor <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
