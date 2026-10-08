import os
import sys
import platform
import psutil
from pathlib import Path
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Anime Dub Studio"
    APP_ENV: str = "development"
    DEBUG: bool = True
    
    # Base paths
    BASE_DIR: Path = Path(__file__).resolve().parent.parent.parent
    STORAGE_DIR: Path = BASE_DIR / "storage"
    PROJECTS_DIR: Path = STORAGE_DIR / "projects"
    MODELS_DIR: Path = BASE_DIR / "models"
    
    # Database
    DATABASE_URL: str = f"sqlite+aiosqlite:///{STORAGE_DIR}/studio.db"
    
    # AI Engine & Services
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    OLLAMA_TRANSLATION_MODEL: str = os.getenv("OLLAMA_TRANSLATION_MODEL", "qwen3.5:4b")
    OLLAMA_FALLBACK_MODEL: str = os.getenv("OLLAMA_FALLBACK_MODEL", "gemma4:e2b")
    COLAB_WORKER_URL: str = os.getenv("COLAB_WORKER_URL", "")
    
    # Default Dub Settings
    DEFAULT_SOURCE_LANG: str = "ja"
    DEFAULT_TARGET_LANG: str = "hi"
    DEFAULT_MALE_VOICE: str = "hi-IN-MadhurNeural"
    DEFAULT_FEMALE_VOICE: str = "hi-IN-SwaraNeural"
    
    # Hardware Worker configuration
    WORKER_PREFERENCE: str = os.getenv("WORKER_PREFERENCE", "auto") # auto, mac, colab
    
    @property
    def is_apple_silicon(self) -> bool:
        return platform.system() == "Darwin" and platform.machine() == "arm64"
    
    @property
    def total_memory_gb(self) -> float:
        return round(psutil.virtual_memory().total / (1024 ** 3), 1)

    @property
    def system_info(self) -> dict:
        return {
            "os": platform.system(),
            "os_release": platform.release(),
            "machine": platform.machine(),
            "is_apple_silicon": self.is_apple_silicon,
            "total_ram_gb": self.total_memory_gb,
            "python_version": sys.version.split()[0],
        }

settings = Settings()

# Ensure directories exist
settings.STORAGE_DIR.mkdir(parents=True, exist_ok=True)
settings.PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
settings.MODELS_DIR.mkdir(parents=True, exist_ok=True)
