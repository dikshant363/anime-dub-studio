use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use tauri::{AppHandle, Manager};
use crate::job_manager::JobManager;

pub fn resolve_resource_root(app: &AppHandle) -> PathBuf {
    // 1. Try Tauri application resource directory
    if let Ok(res_dir) = app.path().resource_dir() {
        if res_dir.join("backend").exists() {
            return res_dir;
        }
    }

    // 2. Try relative to current executable (Contents/MacOS/.. -> Contents/Resources)
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(macos_dir) = exe_path.parent() {
            let res_dir = macos_dir.parent().map(|c| c.join("Resources"));
            if let Some(r) = res_dir {
                if r.join("backend").exists() {
                    return r;
                }
            }
            // In dev (target/debug/anime-dub-studio), walk up to repo root
            let mut cur = macos_dir;
            for _ in 0..6 {
                if cur.join("backend").exists() {
                    return cur.to_path_buf();
                }
                if let Some(p) = cur.parent() {
                    cur = p;
                } else {
                    break;
                }
            }
        }
    }

    // 3. Try current working directory
    if let Ok(cwd) = std::env::current_dir() {
        if cwd.join("backend").exists() {
            return cwd;
        }
    }

    // 4. Fallback to known development root
    let dev_root = PathBuf::from("/Users/dikshantagarwal/Desktop/AUTO DUB");
    if dev_root.join("backend").exists() {
        return dev_root;
    }

    PathBuf::from(".")
}

fn verify_python_candidate(py_path: &Path, resource_root: &Path) -> bool {
    if !py_path.exists() {
        return false;
    }
    let s = py_path.to_string_lossy();
    // REJECT Apple CommandLineTools or bare system python lacking project dependencies
    if s.contains("CommandLineTools") || s == "/usr/bin/python3" || s == "/bin/python3" {
        return false;
    }

    // Execute quick verification check with PYTHONPATH
    let status = Command::new(py_path)
        .arg("-c")
        .arg("import pydantic; import sys; sys.exit(0)")
        .env("PYTHONPATH", resource_root)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    match status {
        Ok(st) => st.success(),
        Err(_) => false,
    }
}

pub fn resolve_python_bin(resource_root: &Path) -> Result<PathBuf, String> {
    let mut candidates: Vec<PathBuf> = Vec::new();

    // 1. Check bundled Python in App Resources
    candidates.push(resource_root.join("python/bin/python"));
    candidates.push(resource_root.join("python/bin/python3"));
    candidates.push(resource_root.join("venv/bin/python"));
    candidates.push(resource_root.join("venv/bin/python3"));
    candidates.push(resource_root.join(".venv/bin/python"));

    // 2. Check if current executable is in an app bundle (Contents/Resources/python)
    if let Ok(exe) = std::env::current_exe() {
        if let Some(macos_dir) = exe.parent() {
            if let Some(contents_dir) = macos_dir.parent() {
                let res = contents_dir.join("Resources");
                candidates.push(res.join("python/bin/python"));
                candidates.push(res.join("python/bin/python3"));
                candidates.push(res.join("venv/bin/python"));
            }
        }
    }

    // 3. Check /Applications/Anime Dub Studio.app
    candidates.push(PathBuf::from("/Applications/Anime Dub Studio.app/Contents/Resources/python/bin/python"));
    candidates.push(PathBuf::from("/Applications/Anime Dub Studio.app/Contents/Resources/python/bin/python3"));
    candidates.push(PathBuf::from("/Applications/Anime Dub Studio.app/Contents/Resources/venv/bin/python"));

    // 4. Check user Application Support venv
    if let Ok(home) = std::env::var("HOME") {
        candidates.push(PathBuf::from(format!("{}/Library/Application Support/Anime Dub Studio/venv/bin/python", home)));
    }

    // 5. Check local repository venv
    candidates.push(resource_root.join(".venv/bin/python"));
    candidates.push(PathBuf::from("/Users/dikshantagarwal/Desktop/AUTO DUB/.venv/bin/python"));

    // 6. Check Homebrew Python 3.12 / 3.11 installs
    candidates.push(PathBuf::from("/opt/homebrew/opt/python@3.12/bin/python3.12"));
    candidates.push(PathBuf::from("/opt/homebrew/bin/python3.12"));
    candidates.push(PathBuf::from("/opt/homebrew/bin/python3"));
    candidates.push(PathBuf::from("/usr/local/bin/python3.12"));
    candidates.push(PathBuf::from("/usr/local/bin/python3"));

    for candidate in candidates {
        if verify_python_candidate(&candidate, resource_root) {
            return Ok(candidate);
        }
    }

    Err(
        "No verified Python 3.12 runtime with required dependencies (pydantic, soundfile, mlx) was found. \
        Please ensure the application bundle includes the Python runtime or a virtual environment is installed."
        .to_string(),
    )
}

pub fn resolve_storage_dir(resource_root: &Path) -> PathBuf {
    // In dev mode: if local ./storage exists and is writable, use it
    let local_storage = resource_root.join("storage");
    if local_storage.exists() {
        let test_file = local_storage.join(".write_test");
        if std::fs::write(&test_file, b"ok").is_ok() {
            let _ = std::fs::remove_file(test_file);
            return local_storage;
        }
    }

    // In production: use user Application Support directory
    if let Ok(home) = std::env::var("HOME") {
        let app_support = PathBuf::from(home).join("Library/Application Support/Anime Dub Studio/storage");
        let _ = std::fs::create_dir_all(&app_support);
        return app_support;
    }

    local_storage
}

pub fn check_macos_speech_voices() -> Result<(), String> {
    if !Path::new("/usr/bin/say").exists() {
        return Err("macOS Speech Synthesizer (/usr/bin/say) is not installed on this system.".to_string());
    }

    let out = Command::new("/usr/bin/say")
        .arg("-v")
        .arg("?")
        .output();

    if let Ok(output) = out {
        let voices_text = String::from_utf8_lossy(&output.stdout);
        let required = ["Rishi", "Lekha", "Aman", "Tara"];
        let mut missing = Vec::new();
        for v in required {
            if !voices_text.contains(v) {
                missing.push(v);
            }
        }
        if !missing.is_empty() {
            eprintln!(
                "[WARN] Some recommended macOS Indian voices are not installed: {}. Using available system voices.",
                missing.join(", ")
            );
        }
    }

    Ok(())
}

pub async fn execute_dubbing(
    app: AppHandle,
    job_manager: JobManager,
    job_id: String,
    media_path_str: String,
    source_lang: String,
    target_lang: String,
    translation_model: String,
    style: String,
    voice_mode: Option<String>,
    audio_stream_index: Option<u32>,
) -> Result<String, String> {
    // 1. Verify input media file exists
    let input_path = Path::new(&media_path_str);
    if !input_path.exists() {
        job_manager.fail_job(
            &app,
            &job_id,
            "Input media file not found",
            Some("The selected video file does not exist or cannot be accessed."),
            Some("Verify that the input video file exists and is accessible."),
        );
        return Err("Input media file not found".to_string());
    }

    // 2. Preflight macOS Speech voices check
    if voice_mode.as_deref() != Some("online") {
        if let Err(e) = check_macos_speech_voices() {
            job_manager.fail_job(
                &app,
                &job_id,
                "macOS Speech Synthesizer unavailable",
                Some(&e),
                Some("Ensure /usr/bin/say is accessible or select Edge-TTS online mode."),
            );
            return Err(e);
        }
    }

    // 3. Resolve Resource Root & Python Runtime
    let resource_root = resolve_resource_root(&app);
    let storage_dir = resolve_storage_dir(&resource_root);

    let python_bin = match resolve_python_bin(&resource_root) {
        Ok(p) => p,
        Err(err) => {
            job_manager.fail_job(
                &app,
                &job_id,
                "The bundled Python runtime could not load the pipeline.",
                Some(&err),
                Some("Verify that the Python runtime and dependencies are packaged inside the application bundle."),
            );
            return Err(err);
        }
    };

    // 4. Construct PATH with Homebrew, user, and bundled bin directories
    let mut path_entries: Vec<PathBuf> = Vec::new();
    let bundled_bin = resource_root.join("bin");
    if bundled_bin.exists() {
        path_entries.push(bundled_bin);
    }
    path_entries.push(PathBuf::from("/opt/homebrew/bin"));
    path_entries.push(PathBuf::from("/usr/local/bin"));
    path_entries.push(PathBuf::from("/usr/bin"));
    path_entries.push(PathBuf::from("/bin"));
    path_entries.push(PathBuf::from("/usr/sbin"));
    path_entries.push(PathBuf::from("/sbin"));
    if let Ok(orig_path) = std::env::var("PATH") {
        for p in std::env::split_paths(&orig_path) {
            if !path_entries.contains(&p) {
                path_entries.push(p);
            }
        }
    }
    let env_path_str = std::env::join_paths(&path_entries).unwrap_or_default();

    // 5. Preflight FFmpeg check
    let ffmpeg_found = Command::new("which")
        .arg("ffmpeg")
        .env("PATH", &env_path_str)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if !ffmpeg_found {
        let err_msg = "FFmpeg executable not found in PATH or application resources.";
        job_manager.fail_job(
            &app,
            &job_id,
            "FFmpeg not found",
            Some(err_msg),
            Some("Please install FFmpeg (e.g. brew install ffmpeg) or bundle it in application resources."),
        );
        return Err(err_msg.to_string());
    }

    // 6. Spawn Python runner with explicit environment configuration
    let mut cmd = Command::new(&python_bin);
    cmd.arg("-u")
        .arg("-m")
        .arg("backend.app.pipeline.runner_cli")
        .arg("--input").arg(&media_path_str)
        .arg("--source-lang").arg(&source_lang)
        .arg("--target-lang").arg(&target_lang)
        .arg("--translation-model").arg(&translation_model)
        .arg("--translation-style").arg(&style)
        .arg("--job-id").arg(&job_id);

    if let Some(vm) = &voice_mode {
        cmd.arg("--voice-mode").arg(vm);
    }
    if let Some(idx) = audio_stream_index {
        cmd.arg("--audio-stream-index").arg(idx.to_string());
    }

    // Explicitly configure execution context
    cmd.current_dir(&resource_root);
    cmd.env("PYTHONPATH", &resource_root);
    cmd.env("STORAGE_DIR", &storage_dir);
    cmd.env("DATABASE_URL", format!("sqlite+aiosqlite:///{}/studio.db", storage_dir.display()));
    cmd.env("PATH", &env_path_str);

    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    let mut child = cmd.spawn().map_err(|e| {
        let err = format!("Failed to spawn Python runner: {}", e);
        job_manager.fail_job(
            &app,
            &job_id,
            "Failed to spawn Python runner",
            Some(&err),
            Some("Ensure Python virtual environment and dependencies are installed."),
        );
        err
    })?;

    let pid = child.id();
    job_manager.register_pid(&job_id, pid);

    let stderr = child.stderr.take();
    let stderr_handle = std::thread::spawn(move || {
        let mut lines = Vec::new();
        if let Some(err) = stderr {
            let r = BufReader::new(err);
            for line in r.lines() {
                if let Ok(l) = line {
                    if !l.trim().is_empty() {
                        lines.push(l);
                    }
                }
            }
        }
        lines.join("\n")
    });

    let stdout = child.stdout.take().ok_or_else(|| "Failed to capture stdout".to_string())?;
    let reader = BufReader::new(stdout);

    let mut final_video_path: Option<String> = None;
    let mut final_qa_score = 96.0;

    for line in reader.lines() {
        if let Ok(l) = line {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&l) {
                let event = v.get("event").and_then(|e| e.as_str()).unwrap_or("");
                if event == "progress" {
                    let stage = v.get("stage").and_then(|s| s.as_str()).unwrap_or("PREPARING");
                    let stage_label = v.get("stage_label").and_then(|s| s.as_str()).unwrap_or("Preparing video");
                    let progress = v.get("progress").and_then(|p| p.as_f64()).unwrap_or(0.0);
                    let message = v.get("message").and_then(|m| m.as_str()).unwrap_or("");
                    let character = v.get("current_character").and_then(|c| c.as_str()).map(|s| s.to_string());
                    let cur_item = v.get("current_item").and_then(|i| i.as_u64()).unwrap_or(0) as usize;
                    let tot_items = v.get("total_items").and_then(|i| i.as_u64()).unwrap_or(0) as usize;
                    let elapsed = v.get("elapsed_seconds").and_then(|e| e.as_u64()).unwrap_or(0);
                    let remaining = v.get("estimated_remaining_seconds").and_then(|r| r.as_u64());
                    let speed = v.get("speed_x").and_then(|s| s.as_f64()).unwrap_or(1.0);
                    let processed_str = v.get("processed_time_str").and_then(|s| s.as_str()).unwrap_or("00:00");
                    let duration_str = v.get("source_duration_str").and_then(|s| s.as_str()).unwrap_or("--:--");
                    let duration_secs = v.get("source_duration_secs").and_then(|s| s.as_f64()).unwrap_or(0.0);
                    let completed_stages = v.get("completed_stages")
                        .and_then(|arr| arr.as_array())
                        .map(|arr| arr.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect())
                        .unwrap_or_default();
                    let voice_provider = v.get("voice_provider").and_then(|vp| vp.as_str()).map(|s| s.to_string());
                    let project_title = v.get("project_title").and_then(|pt| pt.as_str()).map(|s| s.to_string());
                    let source_filename = v.get("source_filename").and_then(|sf| sf.as_str()).map(|s| s.to_string());

                    job_manager.update_progress(
                        &app,
                        &job_id,
                        stage,
                        stage_label,
                        progress,
                        message,
                        character,
                        cur_item,
                        tot_items,
                        elapsed,
                        remaining,
                        speed,
                        processed_str,
                        duration_str,
                        duration_secs,
                        completed_stages,
                        voice_provider,
                        project_title,
                        source_filename,
                    );
                } else if event == "complete" {
                    if let Some(p) = v.get("output_video_path").and_then(|s| s.as_str()) {
                        final_video_path = Some(p.to_string());
                    }
                    if let Some(qa) = v.get("qa_score").and_then(|q| q.as_f64()) {
                        final_qa_score = qa;
                    }
                } else if event == "error" {
                    let err = v.get("error").and_then(|e| e.as_str()).unwrap_or("Pipeline error");
                    let detail = v.get("traceback").and_then(|t| t.as_str()).or_else(|| v.get("detail").and_then(|d| d.as_str()));
                    let recovery = v.get("recovery").and_then(|r| r.as_str()).unwrap_or("Completed checkpoint stages are saved on disk. You can retry from the last checkpoint.");
                    job_manager.fail_job(&app, &job_id, err, detail, Some(recovery));
                    return Err(err.to_string());
                }
            }
        }
    }

    let status = child.wait().map_err(|e| e.to_string())?;
    job_manager.unregister_pid(&job_id);
    let captured_stderr = stderr_handle.join().unwrap_or_default();

    if !status.success() {
        let current_job = job_manager.get_job(&job_id);
        if current_job.as_ref().map(|j| j.status == "CANCELLED").unwrap_or(false) {
            return Err("Job was cancelled by user".to_string());
        }
        if current_job.as_ref().map(|j| j.status == "FAILED").unwrap_or(false) {
            return Err("Pipeline failed".to_string());
        }

        let detail_str = if !captured_stderr.trim().is_empty() {
            captured_stderr.trim()
        } else {
            "Process terminated unexpectedly with no stderr"
        };

        job_manager.fail_job(
            &app,
            &job_id,
            "Python pipeline process exited unexpectedly",
            Some(detail_str),
            Some("Check system logs and retry from checkpoint."),
        );
        return Err(detail_str.to_string());
    }

    if let Some(video) = final_video_path {
        job_manager.complete_job(&app, &job_id, &video, final_qa_score);
        Ok(video)
    } else {
        Err("Pipeline completed without output video".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rejects_command_line_tools_and_system_stub() {
        let root = Path::new("/Users/dikshantagarwal/Desktop/AUTO DUB");
        assert!(!verify_python_candidate(Path::new("/Library/Developer/CommandLineTools/usr/bin/python3"), root));
        assert!(!verify_python_candidate(Path::new("/usr/bin/python3"), root));
        assert!(!verify_python_candidate(Path::new("/bin/python3"), root));
        assert!(!verify_python_candidate(Path::new("/nonexistent/python"), root));
    }

    #[test]
    fn test_resolves_valid_python_runtime() {
        let root = Path::new("/Users/dikshantagarwal/Desktop/AUTO DUB");
        let result = resolve_python_bin(root);
        assert!(result.is_ok(), "Should resolve a valid Python runtime: {:?}", result);
        let py = result.unwrap();
        assert!(py.exists(), "Resolved python must exist: {:?}", py);
        assert!(!py.to_string_lossy().contains("CommandLineTools"), "Must not be CommandLineTools");
    }

    #[test]
    fn test_resolve_storage_dir() {
        let root = Path::new("/Users/dikshantagarwal/Desktop/AUTO DUB");
        let storage = resolve_storage_dir(root);
        assert!(storage.exists(), "Storage directory must exist");
    }
}
