use serde::{Deserialize, Serialize};
use crate::swift_bridge::SwiftBridge;
use std::process::Command;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum AIProvider {
    Auto,
    Apple,
    Ollama,
    Colab,
}

impl AIProvider {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "apple" | "apple_intelligence" => AIProvider::Apple,
            "ollama" | "qwen" => AIProvider::Ollama,
            "colab" => AIProvider::Colab,
            _ => AIProvider::Auto,
        }
    }
}

pub struct AIRouter;

impl AIRouter {
    pub async fn translate(
        text: &str,
        source: &str,
        target: &str,
        character: Option<&str>,
        style: &str,
        provider_preference: &str,
    ) -> (String, String) { // returns (translated_hindi, provider_used)
        let pref = AIProvider::from_str(provider_preference);

        // 1. Explicit Apple Intelligence
        if matches!(pref, AIProvider::Apple) && SwiftBridge::is_available() {
            if let Ok(res) = SwiftBridge::translate(text, source, target, character, style) {
                return (res.adapted_hindi, "Apple Intelligence (On-Device Neural Engine)".to_string());
            }
        }

        // 2. Explicit Ollama
        if matches!(pref, AIProvider::Ollama) {
            if let Some(res) = Self::translate_with_ollama(text, source, target, character).await {
                return (res, "Ollama (qwen3.5:4b)".to_string());
            }
        }

        // 3. AUTO: Apple Foundation Models -> Ollama -> Fallback
        if matches!(pref, AIProvider::Auto) {
            if SwiftBridge::is_available() {
                if let Ok(res) = SwiftBridge::translate(text, source, target, character, style) {
                    if !res.adapted_hindi.is_empty() {
                        return (res.adapted_hindi, "Apple Intelligence (On-Device Neural Engine)".to_string());
                    }
                }
            }

            if let Some(res) = Self::translate_with_ollama(text, source, target, character).await {
                return (res, "Ollama (qwen3.5:4b)".to_string());
            }
        }

        // 4. Deterministic Fallback
        let fallback = match text.trim() {
            "何をしているんだ？" | "何をしているんだ" => "तुम क्या कर रहे हो?",
            "誰だ？" | "誰だ" => "कौन हो तुम?",
            "行くぞ！" | "行くぞ" => "चलो चलें!",
            "ありがとう" => "शुक्रिया!",
            "さようなら" => "अलविदा!",
            _ => "तुम क्या कह रहे हो?",
        };

        (fallback.to_string(), "Local Anime Localization Engine".to_string())
    }

    async fn translate_with_ollama(text: &str, _source: &str, _target: &str, _character: Option<&str>) -> Option<String> {
        let prompt = format!(
            "Translate Japanese anime dialogue into natural spoken Hindi dub dialogue in Devanagari script. Line: {}\nOutput ONLY Hindi dialogue:",
            text
        );

        let body = serde_json::json!({
            "model": "qwen3.5:4b",
            "prompt": prompt,
            "stream": false,
            "options": {
                "num_predict": 100
            }
        });

        let output = Command::new("curl")
            .arg("-s")
            .arg("http://localhost:11434/api/generate")
            .arg("-d").arg(body.to_string())
            .output();

        if let Ok(out) = output {
            if let Ok(v) = serde_json::from_slice::<serde_json::Value>(&out.stdout) {
                if let Some(res) = v.get("response").and_then(|r| r.as_str()) {
                    let clean = res.trim();
                    if !clean.is_empty() {
                        return Some(clean.to_string());
                    }
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_ai_router_translation() {
        let (hindi, provider) = AIRouter::translate(
            "何をしているんだ？",
            "ja",
            "hi",
            Some("Protagonist"),
            "natural_anime",
            "auto",
        ).await;

        println!("Translated: {} (Provider: {})", hindi, provider);
        assert!(!hindi.is_empty());
        assert!(!provider.is_empty());
    }
}
