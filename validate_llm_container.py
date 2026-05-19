#!/usr/bin/env python3
"""
LLM Configuration Validator - Docker Container Version
Runs inside the summary_service or API container.
"""

import os
import sys
import time
import logging
import argparse

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("llm_validator")

SAMPLE_TRANSCRIPT = """
Agent: Hello, thank you for calling support. How can I help you today?
Customer: Hi, I cannot log into my account.
Agent: I can help with that. Can you confirm your email address?
Customer: It is customer@example.com.
Agent: I found the account. A security lock was applied after several failed attempts.
Customer: Can you unlock it?
Agent: Yes, I have unlocked it. Please try again now.
Customer: It works. Thank you.
Agent: You are welcome. Is there anything else I can help with?
Customer: No, that is all.
"""

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

def build_llm_config(backend):
    from parlona.llm import LLMConfig

    backend = (backend or os.environ.get("LLM_BACKEND", "openai")).lower()

    if backend == "openai":
        return LLMConfig(
            backend=backend,
            api_key=os.environ.get("OPENAI_API_KEY"),
            base_url=os.environ.get("OPENAI_BASE_URL"),
            model=os.environ.get("OPENAI_MODEL"),
        )
    if backend == "groq":
        return LLMConfig(
            backend=backend,
            api_key=os.environ.get("GROQ_API_KEY"),
            base_url=os.environ.get("GROQ_BASE_URL"),
            model=os.environ.get("GROQ_MODEL"),
        )
    if backend == "vllm":
        return LLMConfig(
            backend=backend,
            api_key=os.environ.get("VLLM_API_KEY", "EMPTY"),
            base_url=os.environ.get("VLLM_BASE_URL"),
            model=os.environ.get("VLLM_MODEL"),
        )
    if backend == "ollama":
        return LLMConfig(
            backend=backend,
            base_url=os.environ.get("OLLAMA_BASE_URL"),
            model=os.environ.get("OLLAMA_MODEL"),
        )

    raise ValueError(f"Unsupported LLM backend: {backend}")


def main():
    parser = argparse.ArgumentParser(description="Validate LLM configuration inside a VoiceCore container")
    parser.add_argument("--backend", choices=["openai", "vllm", "groq", "ollama"], help="Override LLM backend")
    parser.add_argument("--test-transcript", action="store_true", help="Run summarization on a sample transcript")
    args = parser.parse_args()

    print_section("LLM Configuration Check")
    
    # Check environment variables
    print("\n  Environment Variables:")
    llm_backend = args.backend or os.environ.get('LLM_BACKEND', 'openai')
    print_status("LLM_BACKEND", llm_backend)
    
    # Backend-specific checks
    if llm_backend == "openai":
        api_key = os.environ.get('OPENAI_API_KEY', '')
        model = os.environ.get('OPENAI_MODEL', 'gpt-4o-mini')
        base_url = os.environ.get('OPENAI_BASE_URL', 'https://api.openai.com/v1')
        
        print_status("Model", model)
        print_status("Base URL", base_url)
        if api_key:
            masked = api_key[:10] + "..." + api_key[-5:] if len(api_key) > 15 else "***"
            print_status("API Key", masked)
        else:
            print_status("API Key", "MISSING", is_error=True)
    
    elif llm_backend == "vllm":
        model = os.environ.get('VLLM_MODEL', 'not set')
        base_url = os.environ.get('VLLM_BASE_URL', 'not set')
        print_status("Model", model)
        print_status("Base URL", base_url)
    
    elif llm_backend == "groq":
        api_key = os.environ.get('GROQ_API_KEY', '')
        model = os.environ.get('GROQ_MODEL', 'not set')
        print_status("Model", model)
        if api_key:
            masked = api_key[:10] + "..." + api_key[-5:] if len(api_key) > 15 else "***"
            print_status("API Key", masked)
        else:
            print_status("API Key", "MISSING", is_error=True)
    
    elif llm_backend == "ollama":
        model = os.environ.get('OLLAMA_MODEL', 'not set')
        base_url = os.environ.get('OLLAMA_BASE_URL', 'not set')
        print_status("Model", model)
        print_status("Base URL", base_url)
    
    # Try to initialize LLM client
    print("\n  Testing LLM Client:")
    try:
        start_time = time.time()
        
        # Import LLM components
        from parlona.llm import LLMClient
        
        # Build config from environment
        llm_config = build_llm_config(llm_backend)
        
        print_status("Config Loaded", "OK")
        
        # Initialize client
        print("\n  Initializing LLM client...")
        client = LLMClient(llm_config)
        init_time = time.time() - start_time
        
        print_status("Client Init", f"{init_time:.3f}s")
        print_status("LLM Status", "READY")
        
        # Test connectivity
        print("\n  Testing API connectivity...")
        test_start = time.time()
        
        response = client.client.chat.completions.create(
            model=client.config.model,
            messages=[{"role": "user", "content": "Say 'OK'"}],
            max_tokens=5,
        )
        
        test_time = time.time() - test_start
        content = response.choices[0].message.content.strip()
        
        print_status("API Response", "SUCCESS")
        print_status("Response Time", f"{test_time:.2f}s")
        print_status("Response", content)

        if args.test_transcript:
            print("\n  Testing summarization pipeline...")
            summary_start = time.time()
            summary, headline, language, sentiment_label, entities, sentiment_score = (
                client.summarize_with_headline(SAMPLE_TRANSCRIPT)
            )
            summary_time = time.time() - summary_start

            print_status("Summarization", "SUCCESS")
            print_status("Processing Time", f"{summary_time:.2f}s")
            print_status("Detected Language", language)
            print_status("Sentiment", f"{sentiment_label} ({sentiment_score:.2f})")
            if headline:
                print_status("Headline", headline)
            if summary:
                preview = summary[:180] + "..." if len(summary) > 180 else summary
                print_status("Summary Preview", preview)
            if entities:
                print_status("Entities", str(entities)[:180])
        else:
            print_status("Summarization", "SKIPPED", "Pass --test-transcript to test sample summarization")
        
        print(f"\n{'='*60}")
        print("  ✅ LLM is configured and ready")
        print(f"{'='*60}\n")
        
        return 0
        
    except Exception as e:
        print_status("LLM Status", "FAILED", str(e))
        logger.exception("LLM validation failed")
        print(f"\n{'='*60}")
        print("  ❌ LLM validation failed")
        print(f"{'='*60}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
