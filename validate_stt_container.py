#!/usr/bin/env python3
"""
STT Configuration Validator - Docker Container Version
Runs inside the STT service container.
"""

import os
import sys
import time
import logging
import argparse
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("stt_validator")

def print_section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def print_status(label, status, detail="", is_error=False):
    """Print status with appropriate icon."""
    if is_error:
        status_icon = "❌"
    elif status.lower() in ["ok", "pass", "success", "available", "ready"]:
        status_icon = "✅"
    else:
        # Informational values (not errors, not success)
        status_icon = "ℹ️"
    print(f"  {status_icon} {label}: {status}")
    if detail:
        print(f"     {detail}")

def main():
    parser = argparse.ArgumentParser(description="Validate STT configuration inside the STT container")
    parser.add_argument("--audio-path", help="Optional audio file path to transcribe")
    args = parser.parse_args()

    print_section("STT Configuration Check")
    
    issues = []
    
    # Check environment variables
    print("\n  Environment Variables:")
    stt_enable_gpu = os.environ.get('STT_ENABLE_GPU', '0')
    force_cpu = os.environ.get('FORCE_CPU', '0')
    whisper_model = os.environ.get('STT_MODEL_NAME', 'not set')
    whisper_device = os.environ.get('WHISPER_DEVICE', 'auto')
    
    print_status("STT_ENABLE_GPU", stt_enable_gpu)
    print_status("FORCE_CPU", force_cpu)
    print_status("STT_MODEL_NAME", whisper_model)
    print_status("WHISPER_DEVICE", whisper_device)
    
    # Try to import and test STT
    print("\n  Testing STT Engine:")
    try:
        start_time = time.time()
        
        # Import STT components
        from parlona.stt import STTEngine, STTConfig
        
        # Build config from environment
        local_only = os.getenv("WHISPER_LOCAL_ONLY", "0").lower() in ("1", "true", "yes")
        stt_config = STTConfig(
            model_name=os.getenv("STT_MODEL_NAME", "Systran/faster-whisper-small"),
            device=os.getenv("WHISPER_DEVICE", "auto"),
            compute_type=os.getenv("WHISPER_COMPUTE_TYPE", "float16"),
            diarization_mode=os.getenv("STT_DIARIZATION_MODE", "none"),
            model_dir=os.getenv("WHISPER_MODEL_DIR", "/models/whisper"),
            local_files_only=local_only,
        )
        
        print_status("Config Loaded", "OK")
        print_status("Model", stt_config.model_name)
        
        # Check if GPU was requested but not available
        gpu_requested = stt_enable_gpu == '1' or force_cpu == '0'
        using_cpu = stt_config.resolved_device == 'cpu'
        if gpu_requested and using_cpu:
            print_status("Device", stt_config.resolved_device, "WARNING: GPU requested but not available", is_error=True)
        else:
            print_status("Device", stt_config.resolved_device)
        
        print_status("Compute Type", stt_config.resolved_compute_type)
        
        # Initialize engine
        print("\n  Initializing STT engine...")
        print("  This can take several minutes on first run while the Whisper model is downloaded and loaded.")
        print(f"  Model cache directory: {stt_config.model_dir}")
        print(f"  Local files only: {stt_config.local_files_only}")
        sys.stdout.flush()
        engine = STTEngine(stt_config)
        init_time = time.time() - start_time
        
        print_status("Engine Init", f"{init_time:.2f}s")
        print_status("STT Status", "READY")

        if args.audio_path:
            audio_path = Path(args.audio_path)
            print("\n  Testing transcription:")
            if not audio_path.exists():
                print_status("Test Audio", "FAILED", f"File not found: {audio_path}", is_error=True)
                return 1

            print("  Running transcription. On CPU this may take longer than the audio duration.")
            sys.stdout.flush()
            transcribe_start = time.time()
            result = engine.transcribe(
                str(audio_path),
                diarization_mode=os.getenv("STT_DIARIZATION_MODE", "none"),
            )
            elapsed = time.time() - transcribe_start

            print_status("Transcription", "SUCCESS")
            print_status("Duration", f"{elapsed:.2f}s")
            print_status("Detected Language", result.language or "unknown")
            print_status("Segments", str(len(result.segments)))

            if result.text:
                preview = result.text.replace("\n", " ")
                if len(preview) > 180:
                    preview = preview[:180] + "..."
                print_status("Transcript Preview", preview)

            if result.segments:
                first = result.segments[0]
                print_status("First Segment", f"{first.start:.2f}s - {first.end:.2f}s")
                print(f"     Speaker: {first.speaker or 'N/A'}")
                print(f"     Text: {first.text[:120]}")
        else:
            print_status("Transcription", "SKIPPED", "Pass --audio-path to test real transcription")
        
        print(f"\n{'='*60}")
        print("  ✅ STT is configured and ready")
        print(f"{'='*60}\n")
        
        return 0
        
    except Exception as e:
        print_status("STT Status", "FAILED", str(e))
        logger.exception("STT validation failed")
        print(f"\n{'='*60}")
        print("  ❌ STT validation failed")
        print(f"{'='*60}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
