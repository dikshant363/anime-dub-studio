use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JobProgress {
    pub job_id: String,
    pub stage: String,
    pub progress: f64,
    pub status: String, // QUEUED, RUNNING, COMPLETED, FAILED, CANCELLED
    pub message: String,
    pub output_video_path: Option<String>,
    pub qa_score: Option<f64>,
}

#[derive(Clone)]
pub struct JobManager {
    jobs: Arc<Mutex<HashMap<String, JobProgress>>>,
}

impl JobManager {
    pub fn new() -> Self {
        Self {
            jobs: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn create_job(&self, job_id: String) {
        let mut map = self.jobs.lock().unwrap();
        map.insert(
            job_id.clone(),
            JobProgress {
                job_id,
                stage: "INITIALIZING".to_string(),
                progress: 0.0,
                status: "QUEUED".to_string(),
                message: "Dubbing job queued".to_string(),
                output_video_path: None,
                qa_score: None,
            },
        );
    }

    pub fn update_progress(&self, app: &AppHandle, job_id: &str, stage: &str, progress: f64, message: &str) {
        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.stage = stage.to_string();
            j.progress = progress;
            j.status = if progress >= 100.0 { "COMPLETED".to_string() } else { "RUNNING".to_string() };
            j.message = message.to_string();

            // Emit Tauri event to frontend window
            let _ = app.emit("job-progress", j.clone());
        }
    }

    pub fn complete_job(&self, app: &AppHandle, job_id: &str, video_path: &str, qa_score: f64) {
        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.stage = "COMPLETED".to_string();
            j.progress = 100.0;
            j.status = "COMPLETED".to_string();
            j.message = "Dubbing completed successfully!".to_string();
            j.output_video_path = Some(video_path.to_string());
            j.qa_score = Some(qa_score);

            let _ = app.emit("job-progress", j.clone());
        }
    }

    pub fn fail_job(&self, app: &AppHandle, job_id: &str, error: &str) {
        let mut map = self.jobs.lock().unwrap();
        if let Some(j) = map.get_mut(job_id) {
            j.stage = "FAILED".to_string();
            j.status = "FAILED".to_string();
            j.message = error.to_string();

            let _ = app.emit("job-progress", j.clone());
        }
    }

    pub fn get_job(&self, job_id: &str) -> Option<JobProgress> {
        let map = self.jobs.lock().unwrap();
        map.get(job_id).cloned()
    }
}
