use serde::{Deserialize, Serialize};
use sysinfo::{Disks, System};
use std::process::Command;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SystemCapabilities {
    pub mac_model: String,
    pub chip_name: String,
    pub total_memory_gb: f64,
    pub available_memory_gb: f64,
    pub macos_version: String,
    pub apple_intelligence_available: bool,
    pub foundation_models_available: bool,
    pub apple_intelligence_details: String,
    pub metal_available: bool,
    pub mlx_available: bool,
    pub ollama_available: bool,
    pub ollama_models: Vec<String>,
    pub ffmpeg_installed: bool,
    pub available_disk_gb: f64,
}

pub fn detect_system_capabilities() -> SystemCapabilities {
    let mut sys = System::new_all();
    sys.refresh_all();

    // 1. Memory
    let total_mem_gb = (sys.total_memory() as f64) / (1024.0 * 1024.0 * 1024.0);
    let avail_mem_gb = (sys.available_memory() as f64) / (1024.0 * 1024.0 * 1024.0);

    // 2. Chip & Mac Model
    let chip_name = Command::new("sysctl")
        .arg("-n")
        .arg("machdep.cpu.brand_string")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "Apple Silicon".to_string());

    let mac_model = Command::new("sysctl")
        .arg("-n")
        .arg("hw.model")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "Mac".to_string());

    // 3. macOS Version
    let macos_version = Command::new("sw_vers")
        .arg("-productVersion")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "macOS".to_string());

    // 4. FFmpeg
    let ffmpeg_installed = Command::new("which")
        .arg("ffmpeg")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    // 5. Ollama
    let mut ollama_available = false;
    let mut ollama_models = Vec::new();
    if let Ok(output) = Command::new("ollama").arg("list").output() {
        if output.status.success() {
            ollama_available = true;
            let text = String::from_utf8_lossy(&output.stdout);
            for line in text.lines().skip(1) {
                if let Some(model_name) = line.split_whitespace().next() {
                    ollama_models.push(model_name.to_string());
                }
            }
        }
    }

    // 6. Disk space
    let disks = Disks::new_with_refreshed_list();
    let mut available_disk_gb = 0.0;
    if let Some(primary_disk) = disks.first() {
        available_disk_gb = (primary_disk.available_space() as f64) / (1024.0 * 1024.0 * 1024.0);
    }

    // 7. Apple Intelligence & Foundation Models
    let (ai_avail, fm_avail, ai_desc) = check_apple_intelligence_status();

    SystemCapabilities {
        mac_model,
        chip_name,
        total_memory_gb: (total_mem_gb * 10.0).round() / 10.0,
        available_memory_gb: (avail_mem_gb * 10.0).round() / 10.0,
        macos_version,
        apple_intelligence_available: ai_avail,
        foundation_models_available: fm_avail,
        apple_intelligence_details: ai_desc,
        metal_available: true,
        mlx_available: true,
        ollama_available,
        ollama_models,
        ffmpeg_installed,
        available_disk_gb: (available_disk_gb * 10.0).round() / 10.0,
    }
}

fn check_apple_intelligence_status() -> (bool, bool, String) {
    let output = Command::new(crate::swift_bridge::SwiftBridge::get_service_path())
        .arg("availability")
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            if let Ok(val) = serde_json::from_slice::<serde_json::Value>(&out.stdout) {
                let avail = val.get("data").and_then(|d| d.get("available")).and_then(|b| b.as_bool()).unwrap_or(false);
                let reason = val.get("data").and_then(|d| d.get("reason")).and_then(|s| s.as_str()).unwrap_or("Ready");
                return (avail, avail, reason.to_string());
            }
        }
    }

    (false, false, "Apple Foundation Models unavailable".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_system_capabilities_detect() {
        let caps = detect_system_capabilities();
        println!("Detected Mac: {} - {}", caps.mac_model, caps.chip_name);
        assert!(!caps.chip_name.is_empty());
        assert!(caps.total_memory_gb >= 8.0);
        assert!(caps.ffmpeg_installed);
    }
}
