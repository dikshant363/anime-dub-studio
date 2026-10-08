use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Debug, Serialize, Deserialize)]
pub struct TranslationResult {
    pub source_text: String,
    pub translated_text: String,
    pub adapted_hindi: String,
    pub character: Option<String>,
    pub style: String,
    pub emotion: String,
}

#[allow(dead_code)]
#[derive(Debug, Serialize, Deserialize)]
pub struct EmotionResult {
    pub primary_emotion: String,
    pub intensity: f64,
    pub suggested_speech_rate: f64,
    pub suggested_pitch: f64,
}

#[allow(dead_code)]
#[derive(Debug, Serialize, Deserialize)]
pub struct QualityResult {
    pub score: f64,
    pub is_natural_dub: bool,
    pub critique: String,
}

pub struct SwiftBridge;

impl SwiftBridge {
    pub fn get_service_path() -> std::path::PathBuf {
        for candidate in &[
            "./src-tauri/swift/AppleFoundationModelService",
            "./swift/AppleFoundationModelService",
            "../src-tauri/swift/AppleFoundationModelService",
        ] {
            let p = std::path::PathBuf::from(candidate);
            if p.exists() {
                return p;
            }
        }
        std::path::PathBuf::from("./src-tauri/swift/AppleFoundationModelService")
    }

    pub fn is_available() -> bool {
        let out = Command::new(Self::get_service_path())
            .arg("availability")
            .output();

        if let Ok(o) = out {
            if let Ok(v) = serde_json::from_slice::<serde_json::Value>(&o.stdout) {
                return v.get("data")
                    .and_then(|d| d.get("available"))
                    .and_then(|b| b.as_bool())
                    .unwrap_or(false);
            }
        }
        false
    }

    pub fn translate(text: &str, source: &str, target: &str, character: Option<&str>, style: &str) -> Result<TranslationResult, String> {
        let mut cmd = Command::new(Self::get_service_path());
        cmd.arg("translate")
            .arg("--text").arg(text)
            .arg("--source").arg(source)
            .arg("--target").arg(target)
            .arg("--style").arg(style);

        if let Some(c) = character {
            cmd.arg("--character").arg(c);
        }

        let output = cmd.output().map_err(|e| format!("Failed to run Swift bridge: {}", e))?;
        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).to_string());
        }

        let val: serde_json::Value = serde_json::from_slice(&output.stdout)
            .map_err(|e| format!("JSON parse error: {}", e))?;

        if val.get("status").and_then(|s| s.as_str()) != Some("success") {
            let err = val.get("error").and_then(|e| e.as_str()).unwrap_or("Unknown Swift bridge error");
            return Err(err.to_string());
        }

        let data = val.get("data").ok_or_else(|| "Missing data in response".to_string())?;

        Ok(TranslationResult {
            source_text: data.get("sourceText").and_then(|s| s.as_str()).unwrap_or(text).to_string(),
            translated_text: data.get("translatedText").and_then(|s| s.as_str()).unwrap_or("").to_string(),
            adapted_hindi: data.get("adaptedHindi").and_then(|s| s.as_str()).unwrap_or("").to_string(),
            character: data.get("character").and_then(|s| s.as_str()).map(|s| s.to_string()),
            style: style.to_string(),
            emotion: "neutral".to_string(),
        })
    }

    #[allow(dead_code)]
    pub fn classify_emotion(text: &str) -> Result<EmotionResult, String> {
        let output = Command::new(Self::get_service_path())
            .arg("classify_emotion")
            .arg(text)
            .output()
            .map_err(|e| e.to_string())?;

        let val: serde_json::Value = serde_json::from_slice(&output.stdout)
            .map_err(|e| e.to_string())?;

        let data = val.get("data").ok_or_else(|| "Missing data".to_string())?;
        Ok(EmotionResult {
            primary_emotion: data.get("primaryEmotion").and_then(|s| s.as_str()).unwrap_or("neutral").to_string(),
            intensity: data.get("intensity").and_then(|n| n.as_f64()).unwrap_or(0.7),
            suggested_speech_rate: data.get("suggestedSpeechRate").and_then(|n| n.as_f64()).unwrap_or(1.0),
            suggested_pitch: data.get("suggestedPitch").and_then(|n| n.as_f64()).unwrap_or(0.0),
        })
    }
}
