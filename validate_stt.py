#!/usr/bin/env python3
"""
STT Configuration Validator

Tests Speech-to-Text (Whisper) configuration including:
- GPU availability and acceleration
- Model loading (CPU or GPU)
- Basic transcription capability
- Diarization mode configuration

Usage:
    python validate_stt.py [--audio-path /path/to/test.wav]

The script will:
1. Check environment variables
2. Detect GPU availability
3. Load Whisper model
4. Transcribe a test audio file (if provided)
5. Report configuration status

Exit codes:
    0 - All tests passed
    1 - Configuration errors found
"""

import argparse
import logging
import os
import sys
import time
from pathlib import Path

# Add backend/server to path for imports (supports both OSS and production layouts)
script_dir = Path(__file__).parent
for subdir in ['oss/backend', 'backend', 'server']:
    path = script_dir / subdir
    if path.exists():
        sys.path.insert(0, str(path))
        break

try:
    # Try production layout first (server/)
    from server.workers.stt_worker import STTWorker
    from server.common.config import STTConfig
    HAS_SERVER_LAYOUT = True
except ImportError:
    # Fall back to OSS layout (backend/)
    from backend.stt_service.app.auto_launcher import detect_gpu, configure_whisper_from_env
    from backend.stt_service.app.config import STTServiceSettings
    from backend.stt_service.app.stt_engine import FasterWhisperEngine
    HAS_SERVER_LAYOUT = False

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("stt_validator")

# Test audio duration in seconds (for performance measurement)
TEST_AUDIO_MIN_DURATION = 1.0


def print_section(title: str):
    """Print a formatted section header."""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def print_status(label: str, status: str, detail: str = ""):
    """Print a status line with color-coded status."""
    status_icon = "✅" if status.lower() in ["ok", "pass", "success"] else "❌"
    print(f"  {status_icon} {label}: {status}")
    if detail:
        print(f"     {detail}")


def validate_environment():
    """Validate STT-related environment variables."""
    print_section("1. Environment Variables")
    
    required_vars = [
        "STT_DIARIZATION_MODE",
        "WHISPER_MODEL_DIR",
    ]
    
    optional_vars = [
        "STT_ENABLE_GPU",
        "FORCE_CPU",
        "STT_MODEL_NAME",
        "WHISPER_DEVICE",
        "WHISPER_COMPUTE_TYPE",
        "WHISPER_LOCAL_ONLY",
        "HF_HUB_OFFLINE",
        "STT_STEREO_SPEAKER_MAPPING",
    ]
    
    issues = []
    
    print("\n  Required variables:")
    for var in required_vars:
        value = os.environ.get(var)
        if value:
            print_status(var, value)
        else:
            print_status(var, "MISSING", "Will use default value")
            issues.append(f"Missing required env var: {var}")
    
    print("\n  Optional variables:")
    for var in optional_vars:
        value = os.environ.get(var)
        if value:
            print_status(var, value)
        else:
            print_status(var, "not set", "Using default")
    
    return len(issues) == 0, issues


def validate_gpu_detection():
    """Validate GPU detection logic."""
    print_section("2. GPU Detection")
    
    # Check environment flags
    force_cpu = os.environ.get("FORCE_CPU", "0").lower() in ("1", "true", "yes")
    stt_enable_gpu = os.environ.get("STT_ENABLE_GPU", "").lower()
    
    if force_cpu:
        print_status("FORCE_CPU", "enabled", "GPU will be disabled")
    elif stt_enable_gpu in ("0", "false", "no"):
        print_status("STT_ENABLE_GPU", "disabled", "GPU explicitly disabled")
    elif stt_enable_gpu in ("1", "true", "yes"):
        print_status("STT_ENABLE_GPU", "enabled", "GPU explicitly enabled")
    
    # Run detection
    has_gpu = detect_gpu()
    
    if has_gpu:
        print_status("GPU Status", "AVAILABLE", "CUDA acceleration will be used")
        
        # Try to get GPU info
        try:
            import torch
            gpu_count = torch.cuda.device_count()
            gpu_name = torch.cuda.get_device_name(0)
            gpu_memory = torch.cuda.get_device_properties(0).total_memory / (1024**3)
            print_status("GPU Device", f"{gpu_count}x {gpu_name}", f"{gpu_memory:.1f} GB VRAM")
        except ImportError:
            print_status("GPU Info", "unavailable", "PyTorch not installed")
    else:
        print_status("GPU Status", "NOT AVAILABLE", "Will use CPU inference")
    
    return True, []


def validate_model_loading():
    """Validate Whisper model loading."""
    print_section("3. Model Loading")
    
    issues = []
    
    try:
        # Configure environment
        configure_whisper_from_env()
        
        # Load settings
        settings = STTServiceSettings()
        
        print_status("STT Engine", settings.stt_engine)
        print_status("Model Name", settings.stt_model_name)
        print_status("Device", settings.resolved_device)
        print_status("Compute Type", settings.resolved_compute_type)
        print_status("Model Directory", settings.whisper_model_dir)
        print_status("Local Files Only", str(settings.whisper_local_only))
        print_status("Diarization Mode", settings.diarization_mode)
        
        if settings.diarization_mode == "stereo_channels":
            print_status("Speaker Mapping", settings.stereo_speaker_mapping)
        
        # Check if model directory exists and has cached models
        model_dir = Path(settings.whisper_model_dir)
        if model_dir.exists():
            cache_size = sum(f.stat().st_size for f in model_dir.rglob('*') if f.is_file())
            cache_gb = cache_size / (1024**3)
            print_status("Model Cache", f"{cache_gb:.2f} GB", str(model_dir))
        else:
            print_status("Model Cache", "empty", f"Will download to {model_dir}")
            issues.append(f"Model directory does not exist: {model_dir}")
        
        # Attempt to load the model
        print("\n  Loading Whisper model (this may take a moment)...")
        start_time = time.time()
        
        engine = FasterWhisperEngine(settings)
        
        load_time = time.time() - start_time
        print_status("Model Load Time", f"{load_time:.2f}s")
        
        if load_time < 2.0:
            print_status("Model Status", "CACHED", "Model loaded from cache")
        else:
            print_status("Model Status", "LOADED", "Model may have been downloaded")
        
        return True, issues
        
    except Exception as e:
        print_status("Model Loading", "FAILED", str(e))
        issues.append(f"Model loading failed: {e}")
        return False, issues


def validate_transcription(audio_path: str = None):
    """Validate transcription with test audio."""
    print_section("4. Transcription Test")
    
    issues = []
    
    if not audio_path:
        # Look for test audio in common locations
        test_files = [
            Path("dialogue1s_short.wav"),
            Path("tests/dialogue1s_short.wav"),
            Path("oss/backend/tests/dialogue1s_short.wav"),
        ]
        
        for test_file in test_files:
            if test_file.exists():
                audio_path = str(test_file)
                break
    
    if not audio_path or not Path(audio_path).exists():
        print_status("Transcription", "SKIPPED", "No test audio file found")
        print("\n  Provide a test audio file with: --audio-path /path/to/file.wav")
        print("  Or place a .wav file in the repository root")
        return True, issues
    
    print_status("Test Audio", "found", audio_path)
    
    try:
        # Load settings and engine
        configure_whisper_from_env()
        settings = STTServiceSettings()
        engine = FasterWhisperEngine(settings)
        
        # Run transcription
        print("\n  Running transcription...")
        start_time = time.time()
        
        result = engine.transcribe(
            job_id="test_validation",
            audio_path=audio_path,
            diarization_mode=settings.diarization_mode,
        )
        
        elapsed = time.time() - start_time
        
        # Report results
        print_status("Transcription", "SUCCESS")
        print_status("Duration", f"{elapsed:.2f}s")
        print_status("Detected Language", result.language)
        print_status("Segments", str(len(result.segments)))
        
        if result.text:
            preview = result.text[:100] + "..." if len(result.text) > 100 else result.text
            print_status("Transcript Preview", preview)
        
        if result.segments:
            first_segment = result.segments[0]
            print_status("First Segment", f"{first_segment['start']:.2f}s - {first_segment['end']:.2f}s")
            print(f"     Speaker: {first_segment.get('speaker', 'N/A')}")
            print(f"     Text: {first_segment.get('text', '')[:80]}")
        
        # Performance check
        audio_duration = result.segments[-1]['end'] if result.segments else 0
        if audio_duration > 0:
            realtime_factor = elapsed / audio_duration
            print_status("Realtime Factor", f"{realtime_factor:.2f}x", 
                        f"<1.0 is faster than real-time")
        
        return True, issues
        
    except Exception as e:
        print_status("Transcription", "FAILED", str(e))
        issues.append(f"Transcription failed: {e}")
        logger.exception("Transcription test failed")
        return False, issues


def main():
    """Main validation routine."""
    parser = argparse.ArgumentParser(description="Validate STT configuration")
    parser.add_argument(
        "--audio-path",
        type=str,
        help="Path to test audio file for transcription test",
    )
    args = parser.parse_args()
    
    print("\n" + "="*60)
    print("  ParlonaCore STT Configuration Validator")
    print("="*60)
    print(f"\n  Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    all_issues = []
    all_passed = True
    
    # Run validation steps
    passed, issues = validate_environment()
    all_issues.extend(issues)
    all_passed = all_passed and passed
    
    passed, issues = validate_gpu_detection()
    all_issues.extend(issues)
    all_passed = all_passed and passed
    
    passed, issues = validate_model_loading()
    all_issues.extend(issues)
    all_passed = all_passed and passed
    
    passed, issues = validate_transcription(args.audio_path)
    all_issues.extend(issues)
    all_passed = all_passed and passed
    
    # Final summary
    print_section("VALIDATION SUMMARY")
    
    if all_passed and not all_issues:
        print("\n  ✅ ALL CHECKS PASSED\n")
        print("  STT is configured correctly and ready to use.")
        if not args.audio_path:
            print("  Tip: Run with --audio-path to test transcription.")
        print()
        return 0
    else:
        print(f"\n  ⚠️  {len(all_issues)} ISSUE(S) FOUND\n")
        for i, issue in enumerate(all_issues, 1):
            print(f"  {i}. {issue}")
        print()
        print("  Please fix the issues above before deploying.")
        print()
        return 1


if __name__ == "__main__":
    sys.exit(main())
