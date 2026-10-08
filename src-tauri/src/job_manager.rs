use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JobProgress {
    pub job_id: String,
    pub stage: String,
    pub stage_label: String,
    pub progress: f64,
    pub status: String, // QUEUED, RUNNING, PAUSED, COMPLETED, FAILED, CANCELLED
    pub message: String,
    pub current_character: Option<String>,
    pub current_item: usize,
    pub total_items: usize,
    pub elapsed_seconds: u64,
    pub estimated_remaining_seconds: Option<u64>,
    pub speed_x: f64,
    pub processed_time_str: String,
    pub source_duration_str: String,
    pub source_duration_secs: f64,
    pub output_video_path: Option<String>,
    pub qa_score: Option<f64>,
    pub completed_stages: Vec<String>,
    pub logs: Vec<String>,
    pub project_title: Option<String>,
    pub source_filename: Option<String>,
    pub voice_provider: Option<String>,
    pub active_voice_id: Option<String>,
    pub error_detail: Option<String>,
    pub recovery_action: Option<String>,
}

#[derive(Clone)]
pub struct JobManager {
    jobs: Arc<Mutex<HashMap<String, JobProgress>>>,
    pids: Arc<Mutex<HashMap<String, u32>>>,
}

impl JobManager {
    pub fn new() -> Self {
        Self {
            jobs: Arc::new(Mutex::new(HashMap::new())),
            pids: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn create_job(
        &self,
        job_id: String,
        project_title: Option<String>,
        source_filename: Option<String>,
        voice_provider: Option<String>,
    ) {
        let mut map = self.jobs.lock().unwrap();
        map.insert(
            job_id.clone(),
            JobProgress {
                job_id,
                stage: "PREPARING".to_string(),
                stage_label: "Preparing video".to_string(),
                progress: 0.0,
                status: "QUEUED".to_string(),
                message: "Dubbing job queued".to_string(),
                current_character: None,
                current_item: 0,
                total_items: 0,
                elapsed_seconds: 0,
                estimated_remaining_seconds: None,
                speed_x: 1.0,
                processed_time_str: "00:00".to_string(),
                source_duration_str: "--:--".to_string(),
                source_duration_secs: 0.0,
                output_video_path: None,
                qa_score: None,
                completed_stages: Vec::new(),
                logs: vec!["Dubbing job queued".to_string()],
                project_title,
                source_filename,
                voice_provider: voice_provider.or(Some("Local Apple Silicon".to_string())),
                active_voice_id: None,
                error_detail: None,
                recovery_action: None,
            },
        );
    }

    pub fn register_pid(&self, job_id: &str, pid: u32) {
        let mut pids = self.pids.lock().unwrap();
        pids.insert(job_id.to_string(), pid);
    }

    pub fn unregister_pid(&self, job_id: &str) {
        let mut pids = self.pids.lock().unwrap();
        pids.remove(job_id);
    }

    #[allow(clippy::too_many_arguments)]
    pub fn update_progress(
        &self,
        app: &AppHandle,
        job_id: &str,
        stage: &str,
        stage_label: &str,
        progress: f64,
        message: &str,
        character: Option<String>,
        cur_item: usize,
        tot_items: usize,
        elapsed: u64,
        remaining: Option<u64>,
        speed: f64,
        processed_str: &str,
        duration_str: &str,
        duration_secs: f64,
        completed_stages: Vec<String>,
        voice_provider: Option<String>,
        project_title: Option<String>,
        source_filename: Option<String>,
    ) {
        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.stage = stage.to_string();
            j.stage_label = stage_label.to_string();
            j.progress = progress;
            j.status = if progress >= 100.0 {
                "COMPLETED".to_string()
            } else if j.status == "PAUSED" {
                "PAUSED".to_string()
            } else {
                "RUNNING".to_string()
            };
            j.message = message.to_string();
            j.current_character = character;
            j.current_item = cur_item;
            j.total_items = tot_items;
            j.elapsed_seconds = elapsed;
            j.estimated_remaining_seconds = remaining;
            j.speed_x = speed;
            j.processed_time_str = processed_str.to_string();
            j.source_duration_str = duration_str.to_string();
            j.source_duration_secs = duration_secs;
            j.completed_stages = completed_stages;
            if let Some(vp) = voice_provider {
                j.voice_provider = Some(vp);
            }
            if let Some(pt) = project_title {
                j.project_title = Some(pt);
            }
            if let Some(sf) = source_filename {
                j.source_filename = Some(sf);
            }

            if !j.logs.contains(&message.to_string()) && !message.is_empty() {
                j.logs.push(message.to_string());
            }

            let _ = app.emit("job-progress", j.clone());
        }
    }

    pub fn complete_job(&self, app: &AppHandle, job_id: &str, video_path: &str, qa_score: f64) {
        self.unregister_pid(job_id);
        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.stage = "COMPLETED".to_string();
            j.stage_label = "Complete".to_string();
            j.progress = 100.0;
            j.status = "COMPLETED".to_string();
            j.message = "Dubbing completed successfully!".to_string();
            j.output_video_path = Some(video_path.to_string());
            j.qa_score = Some(qa_score);

            let msg = format!("Dubbing completed! QA Score: {:.1}/100", qa_score);
            if !j.logs.contains(&msg) {
                j.logs.push(msg);
            }

            let _ = app.emit("job-progress", j.clone());
        }
    }

    pub fn fail_job(
        &self,
        app: &AppHandle,
        job_id: &str,
        error: &str,
        error_detail: Option<&str>,
        recovery: Option<&str>,
    ) {
        self.unregister_pid(job_id);
        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.status = "FAILED".to_string();
            j.message = error.to_string();
            j.error_detail = error_detail.map(|s| s.to_string());
            j.recovery_action = recovery.map(|s| s.to_string());

            let err_msg = format!("Error: {}", error);
            if !j.logs.contains(&err_msg) {
                j.logs.push(err_msg);
            }
            if let Some(detail) = error_detail {
                let det_msg = format!("Detail: {}", detail);
                if !j.logs.contains(&det_msg) {
                    j.logs.push(det_msg);
                }
            }

            let _ = app.emit("job-progress", j.clone());
        }
    }

    pub fn cancel_job(&self, app: &AppHandle, job_id: &str) -> bool {
        let pid_opt = {
            let mut pids = self.pids.lock().unwrap();
            pids.remove(job_id)
        };

        if let Some(pid) = pid_opt {
            unsafe {
                libc::kill(pid as i32, libc::SIGTERM);
            }
        }

        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.status = "CANCELLED".to_string();
            j.message = "Dubbing job was cancelled by user.".to_string();
            j.logs.push("Job cancelled by user.".to_string());
            let _ = app.emit("job-progress", j.clone());
            return true;
        }
        false
    }

    pub fn pause_job(&self, app: &AppHandle, job_id: &str) -> bool {
        let pids = self.pids.lock().unwrap();
        if let Some(&pid) = pids.get(job_id) {
            unsafe {
                libc::kill(pid as i32, libc::SIGSTOP);
            }
            let mut map = self.jobs.lock().unwrap();
            if let Some(j) = map.get_mut(job_id) {
                j.status = "PAUSED".to_string();
                j.message = "Dubbing job paused.".to_string();
                j.logs.push("Job paused.".to_string());
                let _ = app.emit("job-progress", j.clone());
                return true;
            }
        }
        false
    }

    pub fn resume_job(&self, app: &AppHandle, job_id: &str) -> bool {
        let pids = self.pids.lock().unwrap();
        if let Some(&pid) = pids.get(job_id) {
            unsafe {
                libc::kill(pid as i32, libc::SIGCONT);
            }
            let mut map = self.jobs.lock().unwrap();
            if let Some(j) = map.get_mut(job_id) {
                j.status = "RUNNING".to_string();
                j.message = "Dubbing job resumed.".to_string();
                j.logs.push("Job resumed.".to_string());
                let _ = app.emit("job-progress", j.clone());
                return true;
            }
        }
        false
    }

    pub fn get_job(&self, job_id: &str) -> Option<JobProgress> {
        let map = self.jobs.lock().unwrap();
        map.get(job_id).cloned()
    }
}
