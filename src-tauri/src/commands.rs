use serde::{Deserialize, Serialize};
use std::process::Command;
use tauri::{AppHandle, State};
use uuid::Uuid;

use crate::job_manager::{JobManager, JobProgress};
use crate::media_probe::{probe_media, MediaMetadata};
use crate::pipeline_runner::execute_dubbing;
use crate::swift_bridge::SwiftBridge;
use crate::system_info::{detect_system_capabilities, SystemCapabilities};

#[derive(Debug, Serialize, Deserialize)]
pub struct StartDubRequest {
    pub file_path: String,
    pub source_language: String,
    pub target_language: String,
    pub translation_model: String,
    pub translation_style: String,
}

#[tauri::command]
pub fn get_system_capabilities() -> SystemCapabilities {
    detect_system_capabilities()
}

#[tauri::command]
pub fn probe_media_file(file_path: String) -> Result<MediaMetadata, String> {
    probe_media(&file_path)
}

#[tauri::command]
pub async fn start_dub_job(
    app: AppHandle,
    job_manager: State<'_, JobManager>,
    req: StartDubRequest,
) -> Result<String, String> {
    let job_id = Uuid::new_v4().to_string();
    job_manager.create_job(job_id.clone());

    let jm = job_manager.inner().clone();
    let jid = job_id.clone();
    let app_handle = app.clone();

    // Spawn non-blocking background task
    tokio::spawn(async move {
        let result = execute_dubbing(
            app_handle.clone(),
            jm.clone(),
            jid.clone(),
            req.file_path,
            req.source_language,
            req.target_language,
            req.translation_model,
            req.translation_style,
        )
        .await;

        if let Err(e) = result {
            jm.fail_job(&app_handle, &jid, &e);
        }
    });

    Ok(job_id)
}

#[tauri::command]
pub fn get_job_status(job_manager: State<'_, JobManager>, job_id: String) -> Option<JobProgress> {
    job_manager.get_job(&job_id)
}

#[tauri::command]
pub fn open_in_finder(path: String) -> Result<(), String> {
    Command::new("open")
        .arg("-R")
        .arg(&path)
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn test_apple_intelligence() -> Result<String, String> {
    if !SwiftBridge::is_available() {
        return Err("Apple Intelligence FoundationModels is currently unavailable".to_string());
    }
    let res = SwiftBridge::translate("何をしているんだ？", "ja", "hi", Some("Lead"), "natural_anime")?;
    Ok(res.adapted_hindi)
}
