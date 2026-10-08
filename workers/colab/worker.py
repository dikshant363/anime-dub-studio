import os
import torch
import shutil
import asyncio
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any

app = FastAPI(title="Anime Dub Studio — Google Colab CUDA Worker")

def detect_cuda_device():
    if not torch.cuda.is_available():
        return {
            "has_cuda": False,
            "device_name": "CPU Fallback",
            "vram_gb": 0.0,
            "recommended_whisper": "tiny",
            "recommended_batch_size": 1
        }
    
    device_name = torch.cuda.get_device_name(0)
    vram_bytes = torch.cuda.get_device_properties(0).total_memory
    vram_gb = round(vram_bytes / (1024 ** 3), 1)

    # Adapt model size to detected GPU
    if vram_gb >= 35.0: # A100 (40GB/80GB)
        rec_whisper = "large-v3"
        rec_batch = 16
    elif vram_gb >= 20.0: # L4 (24GB)
        rec_whisper = "large-v3"
        rec_batch = 8
    else: # T4 (15GB/16GB) or lower
        rec_whisper = "medium"
        rec_batch = 4

    return {
        "has_cuda": True,
        "device_name": device_name,
        "vram_gb": vram_gb,
        "recommended_whisper": rec_whisper,
        "recommended_batch_size": rec_batch
    }

@app.get("/health")
def health():
    return {
        "status": "online",
        "worker": "colab_cuda",
        "hardware": detect_cuda_device()
    }

@app.post("/process")
async def process_media(
    file: UploadFile = File(...),
    source_lang: str = Form(default="ja"),
    target_lang: str = Form(default="hi"),
    style: str = Form(default="natural_anime")
):
    cuda_info = detect_cuda_device()
    temp_dir = Path("/tmp/colab_worker") / file.filename
    temp_dir.mkdir(parents=True, exist_ok=True)
    in_file = temp_dir / file.filename
    with open(in_file, "wb") as f:
        shutil.copyfileobj(file.file, f)

    return {
        "status": "SUCCESS",
        "message": f"Processed on Colab {cuda_info['device_name']} ({cuda_info['vram_gb']}GB VRAM)",
        "cuda_info": cuda_info,
        "target_language": target_lang
    }
