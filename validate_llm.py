#!/usr/bin/env python3
"""
LLM Configuration Validator

Tests LLM backend configuration including:
- Backend selection (OpenAI, vLLM, Groq, Ollama)
- API connectivity
- Model availability
- Basic completion capability

Usage:
    python validate_llm.py [--backend openai|vllm|groq|ollama] [--test-transcript]

The script will:
1. Check environment variables
2. Validate backend configuration
3. Test API connectivity
4. Run a simple completion test
5. Run a full summarization test (optional)
6. Report configuration status

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

# Add backend to path for imports
sys.path.insert(0, str(Path(__file__).parent / "oss" / "backend"))

from backend.common.config import Settings, get_settings
from backend.common.llm_utils import LLMClient

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("llm_validator")

# Sample transcript for testing
SAMPLE_TRANSCRIPT = """
Agent: Hello, thank you for calling support. How can I help you today?
Customer: Hi, I'm having trouble with my account. I can't log in.
Agent: I understand. Can you provide me with your account email?
Customer: Sure, it's customer@example.com.
Agent: Thank you. I can see your account here. It looks like there was a security lock placed on it.
Customer: Oh, I see. What should I do?
Agent: I can unlock it for you right now. Please wait a moment.
Customer: Okay, thank you.
Agent: Your account has been unlocked. Please try logging in again.
Customer: Great, it works now! Thank you so much.
Agent: You're welcome! Is there anything else I can help you with?
Customer: No, that's all. Have a good day!
Agent: You too. Goodbye!
"""


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


def validate_environment(backend_override: str = None):
    """Validate LLM-related environment variables."""
    print_section("1. Environment Variables")
    
    # Check which backend is configured
    configured_backend = backend_override or os.environ.get("LLM_BACKEND", "openai")
    print_status("Configured Backend", configured_backend)
    
    issues = []
    
    # Backend-specific required variables
    backend_configs = {
        "openai": {
            "required": ["OPENAI_API_KEY"],
            "optional": ["OPENAI_BASE_URL", "OPENAI_MODEL"],
            "defaults": {
                "OPENAI_BASE_URL": "https://api.openai.com/v1",
                "OPENAI_MODEL": "gpt-4o-mini",
            }
        },
        "vllm": {
            "required": ["VLLM_BASE_URL"],
            "optional": ["VLLM_MODEL", "VLLM_API_KEY"],
            "defaults": {
                "VLLM_BASE_URL": "http://localhost:8000/v1",
                "VLLM_MODEL": "meta-llama/Meta-Llama-3-8B-Instruct",
                "VLLM_API_KEY": "EMPTY",
            }
        },
        "groq": {
            "required": ["GROQ_API_KEY"],
            "optional": ["GROQ_BASE_URL", "GROQ_MODEL"],
            "defaults": {
                "GROQ_BASE_URL": "https://api.groq.com/openai/v1",
                "GROQ_MODEL": "llama3-8b-8192",
            }
        },
        "ollama": {
            "required": ["OLLAMA_BASE_URL"],
            "optional": ["OLLAMA_MODEL"],
            "defaults": {
                "OLLAMA_BASE_URL": "http://localhost:11434/v1",
                "OLLAMA_MODEL": "llama3",
            }
        }
    }
    
    if configured_backend not in backend_configs:
        print_status("Backend", "INVALID", f"Unsupported backend: {configured_backend}")
        print(f"\n  Supported backends: {', '.join(backend_configs.keys())}")
        return False, [f"Unsupported backend: {configured_backend}"]
    
    config = backend_configs[configured_backend]
    
    print(f"\n  Required variables for {configured_backend}:")
    for var in config["required"]:
        value = os.environ.get(var)
        if value:
            # Mask API keys for security
            if "KEY" in var.upper():
                masked = value[:10] + "..." + value[-5:] if len(value) > 15 else "***"
                print_status(var, masked)
            else:
                print_status(var, value)
        else:
            print_status(var, "MISSING")
            issues.append(f"Missing required env var: {var}")
    
    print(f"\n  Optional variables:")
    for var in config["optional"]:
        value = os.environ.get(var)
        if value:
            print_status(var, value)
        else:
            default = config["defaults"].get(var, "N/A")
            print_status(var, "not set", f"Default: {default}")
    
    return len(issues) == 0, issues


def validate_backend_initialization(backend_override: str = None):
    """Validate that the LLM client can be initialized."""
    print_section("2. Backend Initialization")
    
    issues = []
    
    try:
        # Load settings
        if backend_override:
            os.environ["LLM_BACKEND"] = backend_override
        
        settings = get_settings()
        
        print_status("LLM Backend", settings.llm_backend)
        
        # Backend-specific details
        if settings.llm_backend == "openai":
            print_status("Model", settings.openai_model)
            print_status("Base URL", settings.openai_base_url)
            if settings.openai_api_key:
                masked = settings.openai_api_key[:10] + "..." + settings.openai_api_key[-5:]
                print_status("API Key", masked)
            else:
                print_status("API Key", "MISSING")
                issues.append("OpenAI API key is missing")
        
        elif settings.llm_backend == "vllm":
            print_status("Model", settings.vllm_model)
            print_status("Base URL", settings.vllm_base_url)
        
        elif settings.llm_backend == "groq":
            print_status("Model", settings.groq_model)
            print_status("Base URL", settings.groq_base_url)
            if settings.groq_api_key:
                masked = settings.groq_api_key[:10] + "..." + settings.groq_api_key[-5:]
                print_status("API Key", masked)
            else:
                print_status("API Key", "MISSING")
                issues.append("Groq API key is missing")
        
        elif settings.llm_backend == "ollama":
            print_status("Model", settings.ollama_model)
            print_status("Base URL", settings.ollama_base_url)
        
        # Attempt to initialize the client
        print("\n  Initializing LLM client...")
        start_time = time.time()
        
        client = LLMClient(settings)
        
        init_time = time.time() - start_time
        print_status("Client Init Time", f"{init_time:.3f}s")
        print_status("Client Status", "INITIALIZED")
        
        return client, settings, True, issues
        
    except Exception as e:
        print_status("Client Init", "FAILED", str(e))
        issues.append(f"Client initialization failed: {e}")
        logger.exception("Client initialization failed")
        return None, None, False, issues


def validate_connectivity(client: LLMClient, settings: Settings):
    """Test basic API connectivity."""
    print_section("3. API Connectivity Test")
    
    issues = []
    
    if not client:
        print_status("Connectivity", "SKIPPED", "Client not initialized")
        return False, ["Client not initialized"]
    
    try:
        print(f"\n  Testing connection to {settings.llm_backend}...")
        start_time = time.time()
        
        # Simple test request
        response = client.client.chat.completions.create(
            model=client.model,
            messages=[
                {"role": "user", "content": "Say 'connection test successful' in exactly 3 words"}
            ],
            max_tokens=10,
            temperature=0.0,
        )
        
        elapsed = time.time() - start_time
        content = response.choices[0].message.content.strip()
        
        print_status("API Response", "SUCCESS")
        print_status("Response Time", f"{elapsed:.2f}s")
        print_status("Response", content)
        
        # Performance check
        if elapsed > 10.0:
            print_status("Performance", "SLOW", "Response took >10 seconds")
        else:
            print_status("Performance", "OK")
        
        return True, issues
        
    except Exception as e:
        print_status("API Connectivity", "FAILED", str(e))
        issues.append(f"API connectivity test failed: {e}")
        logger.exception("API connectivity test failed")
        return False, issues


def validate_summarization(client: LLMClient, settings: Settings, test_transcript: bool = False):
    """Test the summarization pipeline."""
    print_section("4. Summarization Test")
    
    issues = []
    
    if not client:
        print_status("Summarization", "SKIPPED", "Client not initialized")
        return False, ["Client not initialized"]
    
    if not test_transcript:
        print_status("Summarization", "SKIPPED", "Use --test-transcript to enable")
        print("\n  This test sends a sample conversation to the LLM for analysis.")
        print("  It tests the full summarization pipeline including:")
        print("    - Summary generation")
        print("    - Headline extraction")
        print("    - Sentiment analysis")
        print("    - Entity extraction")
        return True, issues
    
    try:
        print("\n  Running full summarization test...")
        print(f"  Transcript length: {len(SAMPLE_TRANSCRIPT)} characters")
        start_time = time.time()
        
        # Run summarization
        summary, headline, language, sentiment_label, entities, sentiment_score = \
            client.summarize_with_headline(SAMPLE_TRANSCRIPT)
        
        elapsed = time.time() - start_time
        
        print_status("Summarization", "SUCCESS")
        print_status("Processing Time", f"{elapsed:.2f}s")
        print_status("Detected Language", language)
        print_status("Sentiment", f"{sentiment_label} ({sentiment_score:.2f})")
        
        if headline:
            print_status("Headline", headline)
        
        if summary:
            preview = summary[:120] + "..." if len(summary) > 120 else summary
            print_status("Summary Preview", preview)
        
        if entities:
            entities_preview = str(entities)[:100]
            print_status("Entities Extracted", str(len(entities)), entities_preview)
        
        # Performance check
        if elapsed > 30.0:
            print_status("Performance", "SLOW", "Summarization took >30 seconds")
        else:
            print_status("Performance", "OK")
        
        return True, issues
        
    except Exception as e:
        print_status("Summarization", "FAILED", str(e))
        issues.append(f"Summarization test failed: {e}")
        logger.exception("Summarization test failed")
        return False, issues


def main():
    """Main validation routine."""
    parser = argparse.ArgumentParser(description="Validate LLM configuration")
    parser.add_argument(
        "--backend",
        type=str,
        choices=["openai", "vllm", "groq", "ollama"],
        help="Override LLM backend for testing",
    )
    parser.add_argument(
        "--test-transcript",
        action="store_true",
        help="Run full summarization test with sample transcript",
    )
    args = parser.parse_args()
    
    print("\n" + "="*60)
    print("  ParlonaCore LLM Configuration Validator")
    print("="*60)
    print(f"\n  Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    all_issues = []
    all_passed = True
    
    # Run validation steps
    passed, issues = validate_environment(args.backend)
    all_issues.extend(issues)
    all_passed = all_passed and passed
    
    client, settings, passed, issues = validate_backend_initialization(args.backend)
    all_issues.extend(issues)
    all_passed = all_passed and passed
    
    if client and settings:
        passed, issues = validate_connectivity(client, settings)
        all_issues.extend(issues)
        all_passed = all_passed and passed
        
        passed, issues = validate_summarization(client, settings, args.test_transcript)
        all_issues.extend(issues)
        all_passed = all_passed and passed
    
    # Final summary
    print_section("VALIDATION SUMMARY")
    
    if all_passed and not all_issues:
        print("\n  ✅ ALL CHECKS PASSED\n")
        print("  LLM backend is configured correctly and ready to use.")
        if not args.test_transcript:
            print("  Tip: Run with --test-transcript to test summarization.")
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
