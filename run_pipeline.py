#!/usr/bin/env python3
"""
run_pipeline.py
---------------
GuardianLine core detection pipeline benchmark.

Pipeline:
  Audio File / Text Transcript
      ↓
  [Whisper STT]  — transcribes audio to text
      ↓
  [Phi-3 Mini]   — classifies intent, returns Risk Score (0-10) + Category
      ↓
  [Traffic Light] — Green / Yellow / Red
      ↓
  [Results CSV]  — accuracy, latency, confusion matrix

Usage:
  python run_pipeline.py                  # runs on all files in data/
  python run_pipeline.py --limit 20       # runs on first 20 samples
  python run_pipeline.py --text-only      # skips Whisper, uses .txt transcripts
  python run_pipeline.py --mock-llm       # uses rule-based mock instead of Phi-3
"""

import os
import sys
import json
import time
import argparse
import csv
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Optional

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE_DIR    = Path(__file__).parent
DATA_DIR    = BASE_DIR / "data"
RESULTS_DIR = BASE_DIR / "results"
RESULTS_DIR.mkdir(exist_ok=True)


# ── Data Structures ────────────────────────────────────────────────────────────
@dataclass
class PipelineResult:
    sample_id:        str
    source_file:      str
    true_label:       str           # "scam" or "safe"
    transcript:       str
    risk_score:       float         # 0–10
    category:         str           # "Impersonation", "Urgency", "Safe", etc.
    traffic_light:    str           # "GREEN", "YELLOW", "RED"
    predicted_label:  str           # "scam" if RED/ORANGE, else "safe"
    correct:          bool
    whisper_latency_s: float
    llm_latency_s:    float
    total_latency_s:  float
    error:            Optional[str] = None


# ── Traffic Light Logic ────────────────────────────────────────────────────────
def score_to_traffic_light(score: float) -> tuple[str, str]:
    """Returns (traffic_light, predicted_label)"""
    if score <= 3:
        return "GREEN", "safe"
    elif score <= 6:
        return "YELLOW", "safe"   # Caution but not blocking
    else:
        return "RED", "scam"


# ── Phi-3 Mini System Prompt ───────────────────────────────────────────────────
SYSTEM_PROMPT = """You are GuardianLine, a scam detection AI protecting elderly phone users.

Analyze the following phone call transcript and detect social engineering tactics.

Common scam patterns to detect:
- IMPERSONATION: Pretending to be IRS, Medicare, Social Security, bank, police, grandchild, tech support
- URGENCY: "Act now", "immediate action required", "your account will be closed", "you will be arrested"
- ISOLATION: "Don't tell anyone", "keep this between us", "your family won't understand"
- PAYMENT PRESSURE: Gift cards, wire transfer, cryptocurrency, "processing fee"
- FEAR TACTICS: Threats of arrest, lawsuit, account closure, deportation
- PII HARVESTING: Requesting SSN, Medicare number, bank account, date of birth
- TOO GOOD TO BE TRUE: Lottery winnings, prize money, unclaimed funds

Respond ONLY with a valid JSON object — no explanation, no markdown, no extra text:
{
  "risk_score": <integer 0-10>,
  "category": "<one of: Safe, Impersonation, Urgency, Isolation, PaymentPressure, FearTactic, PIIHarvesting, Lottery, Mixed>",
  "reasoning": "<one sentence max>",
  "hook_detected": <true|false>,
  "red_flags": ["<flag1>", "<flag2>"]
}

Risk score guide:
  0-3  = Safe (normal conversation, no red flags)
  4-6  = Caution (mildly suspicious, unusual request)
  7-10 = Scam (clear social engineering detected)"""


# ── Step 1: Whisper STT ────────────────────────────────────────────────────────
def transcribe_audio(audio_path: str) -> tuple[str, float]:
    """
    Transcribe audio file using OpenAI Whisper.
    Returns (transcript, latency_seconds).
    """
    try:
        import whisper
        print(f"    [Whisper] Loading model (base)...")
        model = whisper.load_model("base")  # "base" is fast enough for PoC
        t0 = time.time()
        result = model.transcribe(audio_path, language="en", fp16=False)
        latency = time.time() - t0
        return result["text"].strip(), latency
    except ImportError:
        raise RuntimeError("Whisper not installed. Run: pip install openai-whisper")
    except Exception as e:
        raise RuntimeError(f"Whisper transcription failed: {e}")


def load_text_transcript(txt_path: str) -> tuple[str, float]:
    """Load a .txt transcript directly (bypasses Whisper)."""
    t0 = time.time()
    text = Path(txt_path).read_text(encoding="utf-8").strip()
    return text, time.time() - t0


# ── Step 2: Phi-3 Mini LLM Inference ──────────────────────────────────────────
_llm_instance = None

def get_llm():
    """Lazy-load Phi-3 Mini via llama-cpp-python (singleton)."""
    global _llm_instance
    if _llm_instance is None:
        try:
            from llama_cpp import Llama
            model_path = BASE_DIR / "models" / "phi-3-mini-4k-instruct.Q4_K_M.gguf"
            if not model_path.exists():
                raise FileNotFoundError(
                    f"Model not found at {model_path}\n"
                    "Download it with:\n"
                    "  python download_model.py\n"
                    "Or manually from: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf"
                )
            print(f"    [Phi-3] Loading model from {model_path}...")
            _llm_instance = Llama(
                model_path=str(model_path),
                n_ctx=2048,
                n_threads=4,
                verbose=False
            )
        except ImportError:
            raise RuntimeError("llama-cpp-python not installed. Run: pip install llama-cpp-python")
    return _llm_instance


def classify_with_llm(transcript: str) -> tuple[dict, float]:
    """
    Run Phi-3 Mini inference on transcript.
    Returns (parsed_response_dict, latency_seconds).
    """
    llm = get_llm()
    prompt = f"<|system|>\n{SYSTEM_PROMPT}<|end|>\n<|user|>\nCall transcript:\n\"{transcript}\"<|end|>\n<|assistant|>"

    t0 = time.time()
    output = llm(
        prompt,
        max_tokens=256,
        temperature=0.1,   # Low temperature for consistent classification
        stop=["<|end|>", "<|user|>"]
    )
    latency = time.time() - t0

    raw_text = output["choices"][0]["text"].strip()

    # Parse JSON response
    try:
        # Strip any accidental markdown fences
        clean = raw_text.replace("```json", "").replace("```", "").strip()
        parsed = json.loads(clean)
        return parsed, latency
    except json.JSONDecodeError:
        # Fallback: extract risk_score with basic parsing
        score = 5.0
        if "risk_score" in raw_text:
            import re
            match = re.search(r'"risk_score"\s*:\s*(\d+)', raw_text)
            if match:
                score = float(match.group(1))
        return {
            "risk_score": score,
            "category": "Unknown",
            "reasoning": raw_text[:100],
            "hook_detected": score > 6,
            "red_flags": []
        }, latency


# ── Step 3: Mock LLM (for testing without Phi-3 download) ─────────────────────
SCAM_KEYWORDS = [
    "irs", "social security", "medicare", "arrest", "warrant", "suspended",
    "gift card", "wire transfer", "bitcoin", "cryptocurrency", "processing fee",
    "don't tell", "keep secret", "grandchild", "tech support", "microsoft",
    "apple", "amazon", "refund", "won", "prize", "lottery", "unclaimed",
    "ssn", "social security number", "account number", "verify your identity",
    "immediate", "urgent", "act now", "limited time", "legal action"
]

def classify_with_mock(transcript: str) -> tuple[dict, float]:
    """Rule-based mock classifier — no model download needed."""
    t0 = time.time()
    text_lower = transcript.lower()
    found_flags = [kw for kw in SCAM_KEYWORDS if kw in text_lower]

    score = min(10, len(found_flags) * 2.5)
    category = "Safe"
    if found_flags:
        if any(k in text_lower for k in ["irs", "arrest", "warrant", "police"]):
            category = "Impersonation"
        elif any(k in text_lower for k in ["gift card", "wire", "bitcoin"]):
            category = "PaymentPressure"
        elif any(k in text_lower for k in ["urgent", "immediate", "act now"]):
            category = "Urgency"
        else:
            category = "Mixed"

    result = {
        "risk_score": round(score, 1),
        "category": category,
        "reasoning": f"Found {len(found_flags)} keyword(s): {', '.join(found_flags[:3])}",
        "hook_detected": score > 6,
        "red_flags": found_flags[:5]
    }
    return result, time.time() - t0


# ── Main Pipeline Runner ───────────────────────────────────────────────────────
def run_pipeline(args) -> list[PipelineResult]:
    """Run the full pipeline on all samples in the data directory."""

    # Load manifest
    manifest_path = DATA_DIR / "manifest.json"
    if not manifest_path.exists():
        print("ERROR: No manifest found. Run: python download_datasets.py first.")
        sys.exit(1)

    with open(manifest_path) as f:
        manifest = json.load(f)

    samples = manifest["files"]
    if args.limit:
        samples = samples[:args.limit]

    print(f"\n{'='*60}")
    print(f"  GuardianLine Pipeline Test")
    print(f"  Samples: {len(samples)} | Mode: {'text-only' if args.text_only else 'audio+STT'} | LLM: {'mock' if args.mock_llm else 'Phi-3 Mini'}")
    print(f"{'='*60}\n")

    results = []
    stats = {"correct": 0, "tp": 0, "fp": 0, "tn": 0, "fn": 0}

    for i, sample in enumerate(samples):
        sample_id = f"sample_{i+1:03d}"
        source    = sample.get("path", "")
        label     = sample.get("label", "unknown")
        print(f"  [{i+1}/{len(samples)}] {Path(source).name} (true: {label})")

        whisper_latency = 0.0
        llm_latency     = 0.0
        transcript      = sample.get("transcript", "")
        error           = None

        try:
            # Step 1: Transcription
            if transcript:
                # Already have transcript (safe call synthetics)
                whisper_latency = 0.0
            elif args.text_only and source.endswith(".txt"):
                transcript, whisper_latency = load_text_transcript(source)
            elif source.endswith(".wav") and not args.text_only:
                transcript, whisper_latency = transcribe_audio(source)
            else:
                transcript = sample.get("transcript", "No transcript available")

            print(f"    Transcript: \"{transcript[:80]}{'...' if len(transcript) > 80 else ''}\"")
            print(f"    Whisper: {whisper_latency:.2f}s")

            # Step 2: Classification
            if args.mock_llm:
                llm_result, llm_latency = classify_with_mock(transcript)
            else:
                llm_result, llm_latency = classify_with_llm(transcript)

            risk_score = float(llm_result.get("risk_score", 5))
            category   = llm_result.get("category", "Unknown")
            print(f"    Risk Score: {risk_score}/10 | Category: {category} | LLM: {llm_latency:.2f}s")

            # Step 3: Traffic Light
            traffic_light, predicted = score_to_traffic_light(risk_score)
            correct = (predicted == label)
            print(f"    Traffic Light: {traffic_light} → Predicted: {predicted} | {'✓' if correct else '✗'}")

            # Update confusion matrix
            if correct:
                stats["correct"] += 1
            if label == "scam" and predicted == "scam":
                stats["tp"] += 1
            elif label == "safe" and predicted == "scam":
                stats["fp"] += 1
            elif label == "safe" and predicted == "safe":
                stats["tn"] += 1
            elif label == "scam" and predicted == "safe":
                stats["fn"] += 1

        except Exception as e:
            error = str(e)
            risk_score, category = 5.0, "Error"
            traffic_light, predicted = "YELLOW", "safe"
            correct = False
            print(f"    ERROR: {e}")

        total_latency = whisper_latency + llm_latency
        results.append(PipelineResult(
            sample_id        = sample_id,
            source_file      = source,
            true_label       = label,
            transcript       = transcript[:500],
            risk_score       = risk_score,
            category         = category,
            traffic_light    = traffic_light,
            predicted_label  = predicted,
            correct          = correct,
            whisper_latency_s = whisper_latency,
            llm_latency_s    = llm_latency,
            total_latency_s  = total_latency,
            error            = error
        ))
        print()

    return results, stats


# ── Results & Reporting ────────────────────────────────────────────────────────
def save_and_report(results: list[PipelineResult], stats: dict):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path  = RESULTS_DIR / f"results_{timestamp}.csv"

    # Save CSV
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=asdict(results[0]).keys())
        writer.writeheader()
        for r in results:
            writer.writerow(asdict(r))

    # Calculate metrics
    total    = len(results)
    accuracy = stats["correct"] / total if total else 0
    tp, fp   = stats["tp"], stats["fp"]
    tn, fn   = stats["tn"], stats["fn"]

    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall    = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1        = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

    valid_results   = [r for r in results if not r.error]
    avg_latency     = sum(r.total_latency_s for r in valid_results) / len(valid_results) if valid_results else 0
    avg_llm_latency = sum(r.llm_latency_s for r in valid_results) / len(valid_results) if valid_results else 0

    # Print summary
    print("=" * 60)
    print("  RESULTS SUMMARY")
    print("=" * 60)
    print(f"  Total Samples : {total}")
    print(f"  Accuracy      : {accuracy:.1%}")
    print(f"  Precision     : {precision:.1%}  (of flagged calls, how many were real scams)")
    print(f"  Recall        : {recall:.1%}  (of real scams, how many did we catch)")
    print(f"  F1 Score      : {f1:.3f}")
    print()
    print(f"  Confusion Matrix:")
    print(f"    True Positives  (caught scams)     : {tp}")
    print(f"    False Positives (false alarms)     : {fp}")
    print(f"    True Negatives  (safe, correct)    : {tn}")
    print(f"    False Negatives (missed scams)     : {fn}")
    print()
    print(f"  Latency (avg):")
    print(f"    Total pipeline : {avg_latency:.2f}s")
    print(f"    LLM only       : {avg_llm_latency:.2f}s")
    print(f"    Target         : <10s")
    print(f"    Status         : {'✓ PASS' if avg_latency < 10 else '✗ FAIL — too slow'}")
    print()
    print(f"  Results saved → {csv_path}")
    print("=" * 60)

    # Save summary JSON
    summary = {
        "timestamp": timestamp,
        "total": total,
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "confusion_matrix": {"tp": tp, "fp": fp, "tn": tn, "fn": fn},
        "avg_total_latency_s": avg_latency,
        "avg_llm_latency_s": avg_llm_latency,
        "latency_target_met": avg_latency < 10
    }
    summary_path = RESULTS_DIR / f"summary_{timestamp}.json"
    with open(summary_path, "w") as f:
        json.dump(summary, f, indent=2)
    print(f"  Summary JSON  → {summary_path}")

    return summary


# ── Entry Point ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GuardianLine Pipeline Benchmark")
    parser.add_argument("--limit",     type=int,  default=None,  help="Max samples to process")
    parser.add_argument("--text-only", action="store_true",      help="Skip Whisper, use .txt files only")
    parser.add_argument("--mock-llm",  action="store_true",      help="Use rule-based mock instead of Phi-3")
    args = parser.parse_args()

    results, stats = run_pipeline(args)
    save_and_report(results, stats)
