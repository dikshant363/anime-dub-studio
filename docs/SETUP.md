# Setup Guide — Anime Dub Studio

This guide describes how to install and run **Anime Dub Studio** locally on your workstation.

---

## 1. Prerequisites

### System Binaries
Ensure you have the following installed on your machine:
- **macOS / Linux**
- **FFmpeg & FFprobe:** `brew install ffmpeg` (macOS) or `sudo apt-get install ffmpeg` (Ubuntu)
- **Python:** 3.11 or 3.12 (`python3 --version`)
- **uv:** (recommended) `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh | sh`
- **Node.js:** v20+ (`node --version`)
- **pnpm:** `npm install -g pnpm`

---

## 2. Backend Setup

1. **Create and activate Python virtual environment:**
   ```bash
   uv venv .venv --python 3.12
   source .venv/bin/activate
   ```

2. **Install dependencies:**
   ```bash
   uv pip install fastapi "uvicorn[standard]" pydantic pydantic-settings sqlalchemy aiosqlite edge-tts soundfile librosa numpy httpx pytest python-multipart psutil greenlet pytest-asyncio mlx-whisper
   ```

3. **Verify Apple Intelligence Bridge (macOS 26+ on Apple Silicon):**
   ```bash
   swiftc -O scripts/apple_intelligence_bridge.swift -o bin/apple_intelligence_bridge
   ./bin/apple_intelligence_bridge --status
   ```

4. **Verify Ollama (Optional Local Fallback):**
   ```bash
   ollama list
   # Recommended model:
   ollama run qwen3.5:4b
   ```

5. **Start the FastAPI backend server:**
   ```bash
   .venv/bin/uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload
   ```

---

## 3. Frontend Setup

1. **Navigate to the frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install frontend dependencies:**
   ```bash
   pnpm install --ignore-scripts
   ```

3. **Start Next.js development server:**
   ```bash
   pnpm dev
   ```
   Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 4. CLI & One-Command Demo

To run the complete end-to-end dubbing pipeline directly from the command line:

```bash
# Check hardware and AI provider status
.venv/bin/python cli/anime_dub.py status

# Generate synthetic sample test video
.venv/bin/python scripts/generate_synthetic_sample.py

# Run complete one-command demo
.venv/bin/python cli/anime_dub.py demo ./tests/test_data/sample.mp4 --target hi
```

The dubbed video and subtitles will be rendered to:
`storage/projects/<project_id>/episodes/<episode_id>/export/`
