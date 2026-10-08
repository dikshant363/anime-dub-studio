from fastapi import APIRouter
from backend.app.config import settings
from backend.app.pipeline.translation.apple_intelligence import AppleIntelligenceTranslationEngine
from backend.app.pipeline.translation.ollama import OllamaTranslationEngine

router = APIRouter(prefix="/api/system", tags=["System"])

@router.get("/status")
async def get_system_status():
    apple_engine = AppleIntelligenceTranslationEngine()
    ollama_engine = OllamaTranslationEngine()

    apple_available = await apple_engine.is_available()
    ollama_available = await ollama_engine.is_available()

    return {
        "hardware": settings.system_info,
        "workers": {
            "m4_apple_silicon": {
                "available": settings.is_apple_silicon,
                "unified_memory_gb": settings.total_memory_gb,
                "frameworks": ["MLX", "Metal", "FoundationModels"]
            },
            "colab_cuda": {
                "configured": bool(settings.COLAB_WORKER_URL),
                "url": settings.COLAB_WORKER_URL or None
            }
        },
        "providers": {
            "apple_intelligence": {
                "available": apple_available,
                "status": "Ready (On-Device Neural Engine)" if apple_available else "Unavailable",
                "on_device": True
            },
            "ollama": {
                "available": ollama_available,
                "status": f"Ready ({settings.OLLAMA_TRANSLATION_MODEL})" if ollama_available else "Not reachable",
                "base_url": settings.OLLAMA_BASE_URL,
                "model": settings.OLLAMA_TRANSLATION_MODEL
            },
            "tts": {
                "default_male": settings.DEFAULT_MALE_VOICE,
                "default_female": settings.DEFAULT_FEMALE_VOICE,
                "providers": ["EdgeTTS Neural", "Piper ONNX", "Synthetic Tone"]
            }
        }
    }
