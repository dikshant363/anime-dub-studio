from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from backend.app.database import get_db
from backend.app.models.character import Character
from backend.app.schemas.character import CharacterCreate, CharacterUpdate, CharacterResponse

router = APIRouter(prefix="/api/characters", tags=["Characters"])

@router.get("/project/{project_id}", response_model=List[CharacterResponse])
async def list_project_characters(project_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Character).where(Character.project_id == project_id))
    return result.scalars().all()

@router.post("", response_model=CharacterResponse)
async def create_character(data: CharacterCreate, db: AsyncSession = Depends(get_db)):
    char = Character(
        project_id=data.project_id,
        name=data.name,
        speaker_tag=data.speaker_tag,
        gender=data.gender,
        age_group=data.age_group,
        voice_provider=data.voice_provider,
        voice_id=data.voice_id,
        pitch=data.pitch,
        speed=data.speed,
        personality=data.personality,
        speaking_style=data.speaking_style
    )
    db.add(char)
    await db.commit()
    await db.refresh(char)
    return char

@router.put("/{character_id}", response_model=CharacterResponse)
async def update_character(character_id: str, data: CharacterUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Character).where(Character.id == character_id))
    char = result.scalar_one_or_none()
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")

    for k, v in data.dict(exclude_unset=True).items():
        setattr(char, k, v)

    await db.commit()
    await db.refresh(char)
    return char
