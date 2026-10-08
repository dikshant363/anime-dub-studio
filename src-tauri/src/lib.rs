mod system_info;
mod swift_bridge;
mod ai_router;
mod media_probe;
mod job_manager;
mod pipeline_runner;
mod commands;

use job_manager::JobManager;
use commands::*;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .manage(JobManager::new())
        .invoke_handler(tauri::generate_handler![
            get_system_capabilities,
            probe_media_file,
            start_dub_job,
            get_job_status,
            cancel_dub_job,
            pause_dub_job,
            resume_dub_job,
            open_in_finder,
            test_apple_intelligence
        ])
        .run(tauri::generate_context!())
        .expect("error while running Anime Dub Studio macOS desktop app");
}
