from pathlib import Path
from typing import List, Dict, Any

class SubtitleFormatter:
    """Generates Hindi SRT and stylized ASS subtitle files."""

    @staticmethod
    def format_srt_time(seconds: float) -> str:
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int(round((seconds - int(seconds)) * 1000))
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

    @staticmethod
    def format_ass_time(seconds: float) -> str:
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        centis = int(round((seconds - int(seconds)) * 100))
        return f"{hours:d}:{minutes:02d}:{secs:02d}.{centis:02d}"

    @classmethod
    def generate_srt(cls, segments: List[Dict[str, Any]], output_path: Path) -> Path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        lines = []

        for idx, seg in enumerate(segments, 1):
            start = cls.format_srt_time(float(seg["start_time"]))
            end = cls.format_srt_time(float(seg["end_time"]))
            text = seg.get("adapted_hindi_text") or seg.get("translated_text") or seg.get("source_text", "")

            lines.append(str(idx))
            lines.append(f"{start} --> {end}")
            lines.append(text.strip())
            lines.append("")

        output_path.write_text("\n".join(lines), encoding="utf-8")
        return output_path

    @classmethod
    def generate_ass(cls, segments: List[Dict[str, Any]], output_path: Path, title: str = "Anime Dub Subtitles") -> Path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        header = f"""[Script Info]
Title: {title}
ScriptType: v4.00+
WrapStyle: 0
ScaledBorderAndShadow: yes
YCbCr Matrix: None

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,1,0,0,0,100,100,0,0,1,2,1,2,10,10,20,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
        events = []
        for seg in segments:
            start = cls.format_ass_time(float(seg["start_time"]))
            end = cls.format_ass_time(float(seg["end_time"]))
            text = seg.get("adapted_hindi_text") or seg.get("translated_text") or seg.get("source_text", "")
            actor = seg.get("speaker_label", "Character")
            events.append(f"Dialogue: 0,{start},{end},Default,{actor},0,0,0,,{text.strip()}")

        content = header + "\n".join(events) + "\n"
        output_path.write_text(content, encoding="utf-8")
        return output_path
