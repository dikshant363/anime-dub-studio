use serde::{Deserialize, Serialize};
use std::path::Path;
use std::process::Command;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AudioStreamInfo {
    pub index: u32,
    pub stream_index: u32,
    pub codec_name: String,
    pub channels: u32,
    pub sample_rate: u32,
    pub language: Option<String>,
    pub title: Option<String>,
    pub is_japanese: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MediaMetadata {
    pub file_path: String,
    pub filename: String,
    pub file_size_mb: f64,
    pub duration_secs: f64,
    pub fps: f64,
    pub resolution: String,
    pub video_codec: Option<String>,
    pub audio_codec: Option<String>,
    pub audio_channels: u32,
    pub audio_sample_rate: u32,
    pub audio_tracks_count: usize,
    pub subtitle_tracks_count: usize,
    pub audio_streams: Vec<AudioStreamInfo>,
    pub has_enough_disk_space: bool,
}

pub fn probe_media(file_path_str: &str) -> Result<MediaMetadata, String> {
    let path = Path::new(file_path_str);
    if !path.exists() {
        return Err(format!("File does not exist: {}", file_path_str));
    }

    let metadata = path.metadata().map_err(|e| e.to_string())?;
    let file_size_mb = (metadata.len() as f64) / (1024.0 * 1024.0);

    let output = Command::new("ffprobe")
        .arg("-v").arg("quiet")
        .arg("-print_format").arg("json")
        .arg("-show_format")
        .arg("-show_streams")
        .arg(file_path_str)
        .output()
        .map_err(|e| format!("Failed to run ffprobe: {}", e))?;

    if !output.status.success() {
        return Err("ffprobe failed to inspect media".to_string());
    }

    let json_val: serde_json::Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("JSON parse error: {}", e))?;

    let format_info = json_val.get("format");
    let streams = json_val.get("streams").and_then(|s| s.as_array());

    let mut video_codec = None;
    let mut audio_codec = None;
    let mut fps = 24.0;
    let mut resolution = "1920x1080".to_string();
    let mut audio_channels = 2;
    let mut audio_sample_rate = 48000;
    let mut audio_tracks_count = 0;
    let mut subtitle_tracks_count = 0;
    let mut audio_streams = Vec::new();

    if let Some(stream_arr) = streams {
        for s in stream_arr {
            let codec_type = s.get("codec_type").and_then(|c| c.as_str()).unwrap_or("");
            if codec_type == "video" && video_codec.is_none() {
                video_codec = s.get("codec_name").and_then(|c| c.as_str()).map(|c| c.to_string());
                let w = s.get("width").and_then(|w| w.as_u64()).unwrap_or(1920);
                let h = s.get("height").and_then(|h| h.as_u64()).unwrap_or(1080);
                resolution = format!("{}x{}", w, h);
                if let Some(r_rate) = s.get("r_frame_rate").and_then(|r| r.as_str()) {
                    let parts: Vec<&str> = r_rate.split('/').collect();
                    if parts.len() == 2 {
                        let num: f64 = parts[0].parse().unwrap_or(24.0);
                        let den: f64 = parts[1].parse().unwrap_or(1.0);
                        if den > 0.0 {
                            fps = (num / den * 100.0).round() / 100.0;
                        }
                    }
                }
            } else if codec_type == "audio" {
                let stream_idx = s.get("index").and_then(|i| i.as_u64()).unwrap_or(audio_tracks_count as u64) as u32;
                let c_name = s.get("codec_name").and_then(|c| c.as_str()).unwrap_or("aac").to_string();
                let ch = s.get("channels").and_then(|c| c.as_u64()).unwrap_or(2) as u32;
                let sr = s.get("sample_rate").and_then(|sr| sr.as_str()).and_then(|sr| sr.parse().ok()).unwrap_or(48000);
                let tags = s.get("tags");
                let lang = tags.and_then(|t| t.get("language")).and_then(|l| l.as_str()).map(|l| l.to_string());
                let title = tags.and_then(|t| t.get("title")).and_then(|t| t.as_str()).map(|t| t.to_string());
                let is_jpn = lang.as_deref().map(|l| l.eq_ignore_ascii_case("jpn") || l.eq_ignore_ascii_case("ja") || l.eq_ignore_ascii_case("japanese")).unwrap_or(false)
                    || title.as_deref().map(|t| t.to_lowercase().contains("japanese") || t.to_lowercase().contains("jpn")).unwrap_or(false);

                audio_streams.push(AudioStreamInfo {
                    index: audio_tracks_count as u32,
                    stream_index: stream_idx,
                    codec_name: c_name.clone(),
                    channels: ch,
                    sample_rate: sr,
                    language: lang,
                    title,
                    is_japanese: is_jpn,
                });

                audio_tracks_count += 1;
                if audio_codec.is_none() {
                    audio_codec = Some(c_name);
                    audio_channels = ch;
                    audio_sample_rate = sr;
                }
            } else if codec_type == "subtitle" {
                subtitle_tracks_count += 1;
            }
        }
    }

    let duration_secs = format_info
        .and_then(|f| f.get("duration"))
        .and_then(|d| d.as_str())
        .and_then(|d| d.parse::<f64>().ok())
        .unwrap_or(0.0);

    let filename = path.file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "media".to_string());

    Ok(MediaMetadata {
        file_path: file_path_str.to_string(),
        filename,
        file_size_mb: (file_size_mb * 10.0).round() / 10.0,
        duration_secs: (duration_secs * 10.0).round() / 10.0,
        fps,
        resolution,
        video_codec,
        audio_codec,
        audio_channels,
        audio_sample_rate,
        audio_tracks_count,
        subtitle_tracks_count,
        audio_streams,
        has_enough_disk_space: true,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_probe_sample_mp4() {
        let meta = probe_media("../tests/test_data/sample.mp4").expect("probe failed");
        assert_eq!(meta.resolution, "1280x720");
        assert_eq!(meta.fps, 24.0);
        assert_eq!(meta.audio_channels, 1);
        assert!(meta.duration_secs >= 4.0);
        assert_eq!(meta.audio_streams.len(), 1);
    }
}
