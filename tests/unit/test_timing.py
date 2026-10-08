import pytest
from pathlib import Path
from backend.app.pipeline.timing.engine import TimingEngine

@pytest.mark.asyncio
async def test_timing_engine_clamping(tmp_path):
    # Test ratio clamping calculation without audio
    ratio_normal = 1.02
    # If ratio is close to 1.0, stretch is not required
    out_file = tmp_path / "out.wav"
    dummy_in = tmp_path / "dummy.wav"
    dummy_in.write_bytes(b"dummy")

    # Call with duration within tolerance
    _, dur, factor = await TimingEngine.adjust_audio_timing(
        input_audio_path=dummy_in,
        output_audio_path=out_file,
        target_duration=2.0,
        current_duration=2.04
    )
    assert factor == 1.0
