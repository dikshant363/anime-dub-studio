from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List

from backend.app.database import get_db
from backend.app.models.episode import Episode
from backend.app.models.dialogue import DialogueSegment
from backend.app.schemas.episode import EpisodeResponse
from backend.app.schemas.dialogue import DialogueSegmentUpdate, DialogueSegmentResponse

router = APIRouter(prefix="/api/episodes", tags=["Episodes"])

@router.get("/{episode_id}", response_model=EpisodeResponse)
async def get_episode(episode_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Episode)
        .options(selectinload(Episode.dialogues))
        .where(Episode.id == episode_id)
    )
    episode = result.scalar_one_or_none()
    if not episode:
        raise HTTPException(status_code=404, detail="Episode not found")
    return episode

@router.put("/{episode_id}/segments/{segment_id}", response_model=DialogueSegmentResponse)
async def update_segment(
    episode_id: str,
    segment_id: str,
    update_data: DialogueSegmentUpdate,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(DialogueSegment)
        .where(DialogueSegment.id == segment_id, DialogueSegment.episode_id == episode_id)
    )
    seg = result.scalar_one_or_none()
    if not seg:
        raise HTTPException(status_code=404, detail="Dialogue segment not found")

    if update_data.adapted_hindi_text is not None:
        seg.adapted_hindi_text = update_data.adapted_hindi_text
    if update_data.adapted_hinglish_text is not None:
        seg.adapted_hinglish_text = update_data.adapted_hinglish_text
    if update_data.character_id is not None:
        seg.character_id = update_data.character_id
    if update_data.speaker_label is not None:
        seg.speaker_label = update_data.speaker_label
    if update_data.emotion is not None:
        seg.emotion = update_data.emotion
    if update_data.speed_factor is not None:
        seg.speed_factor = update_data.speed_factor
    if update_data.start_time is not None:
        seg.start_time = update_data.start_time
    if update_data.end_time is not None:
        seg.end_time = update_data.end_time

    await db.commit()
    await db.refresh(seg)
    return seg
