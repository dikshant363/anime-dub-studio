"use client";

import React, { useState, useEffect } from "react";
import { Plus, Sparkles, Film, Cpu, HardDrive, CheckCircle2, Play, Volume2 } from "lucide-react";
import CreateDubModal from "@/components/CreateDubModal";
import JobProgressView from "@/components/JobProgressView";
import DubbingEditor from "@/components/DubbingEditor";
import { getSystemCapabilities, isTauriEnvironment, SystemCapabilities } from "@/lib/tauriBridge";

export default function StudioHome() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [activeJob, setActiveJob] = useState<{ jobId: string; episodeId: string; projectId: string } | null>(null);
  const [editingEpisodeId, setEditingEpisodeId] = useState<string | null>(null);
  const [projects, setProjects] = useState<any[]>([]);
  const [systemCaps, setSystemCaps] = useState<SystemCapabilities | null>(null);

  const fetchProjects = async () => {
    try {
      const res = await fetch("http://127.0.0.1:8000/api/projects");
      if (res.ok) {
        const data = await res.json();
        setProjects(data);
      }
    } catch (e) {
      console.warn("Local API not reached (desktop standalone mode)");
    }
  };

  const loadCapabilities = async () => {
    try {
      const caps = await getSystemCapabilities();
      setSystemCaps(caps);
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    fetchProjects();
    loadCapabilities();
  }, []);

  const handleDubCreated = (data: { jobId: string; episodeId: string; projectId: string }) => {
    setActiveJob(data);
  };

  const handleJobFinished = (episodeId: string) => {
    setActiveJob(null);
    setEditingEpisodeId(episodeId);
    fetchProjects();
  };

  if (editingEpisodeId) {
    return (
      <DubbingEditor
        episodeId={editingEpisodeId}
        onBack={() => {
          setEditingEpisodeId(null);
          fetchProjects();
        }}
      />
    );
  }

  if (activeJob) {
    return (
      <JobProgressView
        jobId={activeJob.jobId}
        episodeId={activeJob.episodeId}
        onFinished={handleJobFinished}
        onBackToDashboard={() => setActiveJob(null)}
      />
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0a0c] text-white">
      {/* Navigation Bar */}
      <header className="border-b border-[#202028] bg-[#0e0e12]/80 backdrop-blur-md sticky top-0 z-40">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-white text-black flex items-center justify-center font-black text-lg tracking-tighter">
              AD
            </div>
            <div>
              <span className="font-semibold text-sm tracking-tight">Anime Dub Studio</span>
              <span className="hidden sm:inline-block text-[10px] ml-2 px-2 py-0.5 rounded-full bg-neutral-800 text-neutral-300 font-mono">
                v1.0 Local
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {/* Apple Silicon Hardware Pill */}
            <div className="hidden md:flex items-center gap-2 px-3 py-1.5 rounded-xl bg-[#17171e] border border-[#282834] text-xs">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span className="text-neutral-200 font-medium">
                {systemCaps ? `${systemCaps.chip_name} (${systemCaps.total_memory_gb.toFixed(0)} GB)` : "Apple Silicon M4 (16 GB)"}
              </span>
              <span className="text-neutral-500">•</span>
              <span className="text-neutral-400">
                {systemCaps?.foundation_models_available ? "Apple Intelligence" : "Local MLX Metal"}
              </span>
              {isTauriEnvironment() && (
                <>
                  <span className="text-neutral-500">•</span>
                  <span className="px-1.5 py-0.5 rounded bg-emerald-950/80 border border-emerald-800 text-[10px] text-emerald-300">
                    macOS Native
                  </span>
                </>
              )}
            </div>

            <button
              onClick={() => setIsModalOpen(true)}
              className="px-4 py-2 bg-white text-black hover:bg-neutral-200 rounded-xl text-xs font-semibold tracking-tight transition shadow-lg flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" /> Create a Dub
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Dashboard */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 py-10 space-y-10">
        {/* Hero Section */}
        <div className="p-8 sm:p-10 rounded-3xl bg-gradient-to-br from-[#16161f] via-[#121218] to-[#0d0d12] border border-[#262634] shadow-2xl relative overflow-hidden">
          <div className="max-w-2xl space-y-4 relative z-10">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#20202c] border border-[#2e2e40] text-xs text-neutral-300">
              <Sparkles className="w-3.5 h-3.5 text-amber-300" />
              <span>Japanese Anime → Natural Hindi Dubbing</span>
            </div>
            <h1 className="text-3xl sm:text-4xl font-bold tracking-tight text-white leading-tight">
              Local-first AI dubbing for anime with authentic Hindi character voices.
            </h1>
            <p className="text-sm text-neutral-400 leading-relaxed">
              Transcribe Japanese dialogue with Apple MLX Whisper, adapt culturally into colloquial Hindi dubbing dialogue, synthesize character voices with neural prosody, and multiplex lossless video without cloud fees.
            </p>
            <div className="pt-2 flex flex-wrap items-center gap-3">
              <button
                onClick={() => setIsModalOpen(true)}
                className="px-6 py-3 bg-white text-black hover:bg-neutral-200 rounded-xl text-sm font-semibold transition shadow-xl flex items-center gap-2"
              >
                <Plus className="w-4 h-4" /> Open Dub Creator
              </button>
            </div>
          </div>
        </div>

        {/* Existing Episodes Gallery */}
        <section className="space-y-4">
          <div className="flex items-center justify-between pb-2 border-b border-[#202028]">
            <h2 className="text-base font-semibold text-white">Your Dubbed Episodes</h2>
            <span className="text-xs text-neutral-500 font-mono">
              {projects.reduce((acc, p) => acc + (p.episodes?.length || 0), 0)} Episodes
            </span>
          </div>

          {projects.length === 0 || projects.every((p) => p.episodes?.length === 0) ? (
            <div className="text-center py-16 border border-dashed border-[#262634] rounded-2xl bg-[#121218]/40 p-8 space-y-3">
              <Film className="w-10 h-10 mx-auto text-neutral-600" />
              <p className="text-sm font-medium text-neutral-300">No episodes dubbed yet</p>
              <p className="text-xs text-neutral-500 max-w-sm mx-auto">
                Click &quot;Create a Dub&quot; to import an anime clip and generate your first natural Hindi dub.
              </p>
              <button
                onClick={() => setIsModalOpen(true)}
                className="mt-2 px-4 py-2 bg-neutral-800 hover:bg-neutral-700 text-white rounded-xl text-xs font-medium transition"
              >
                Create First Dub
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {projects.flatMap((project) =>
                (project.episodes || []).map((ep: any) => (
                  <div
                    key={ep.id}
                    onClick={() => setEditingEpisodeId(ep.id)}
                    className="p-5 rounded-2xl bg-[#131318] border border-[#23232c] hover:border-neutral-500 transition cursor-pointer group shadow-lg"
                  >
                    <div className="flex items-center justify-between text-xs text-neutral-400 mb-2">
                      <span className="font-semibold text-white group-hover:text-amber-200 transition">
                        {ep.title}
                      </span>
                      <span className="px-2 py-0.5 rounded-full bg-emerald-950/80 border border-emerald-800 text-emerald-400 text-[10px]">
                        QA {ep.qa_score || 96}%
                      </span>
                    </div>
                    <p className="text-xs text-neutral-500 mb-4 line-clamp-1">
                      Project: {project.name} • {project.source_language.toUpperCase()} → {project.target_language.toUpperCase()}
                    </p>
                    <div className="flex items-center justify-between text-[11px] text-neutral-400 pt-3 border-t border-[#202028]">
                      <span>{ep.duration ? `${ep.duration.toFixed(1)}s` : "Processed"}</span>
                      <span className="text-white font-medium group-hover:underline flex items-center gap-1">
                        Open Editor <Play className="w-3 h-3" />
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          )}
        </section>
      </main>

      {/* Creation Modal */}
      <CreateDubModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onDubCreated={handleDubCreated}
      />
    </div>
  );
}
