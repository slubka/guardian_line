#!/usr/bin/env python3
"""
download_datasets.py
--------------------
Downloads and prepares audio datasets for GuardianLine pipeline testing.

Sources:
  1. FTC Robocall Audio Dataset (NC State / GitHub) - real robocall WAV files + transcripts
  2. Scam Dialogue Dataset (HuggingFace) - text transcripts for prompt tuning
  3. Sample "safe" calls - synthesized or public domain normal conversations
"""

import csv
import json
import requests
from pathlib import Path
from tqdm import tqdm

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE_DIR    = Path(__file__).parent
DATA_DIR    = BASE_DIR / "data"
SCAM_DIR    = DATA_DIR / "scam"
SAFE_DIR    = DATA_DIR / "safe"
RESULTS_DIR = BASE_DIR / "results"

for d in [SCAM_DIR, SAFE_DIR, RESULTS_DIR]:
    d.mkdir(parents=True, exist_ok=True)


# ── 1. FTC Robocall Dataset (GitHub - wspr-ncsu) ───────────────────────────────
# Metadata columns: file_name, language, transcript, case_details, case_pdf
# Audio path:       audio-wav-16khz/<file_name>
FTC_RAW_BASE = "https://raw.githubusercontent.com/wspr-ncsu/robocall-audio-dataset/main/audio-wav-16khz"
FTC_META_URL = "https://raw.githubusercontent.com/wspr-ncsu/robocall-audio-dataset/main/metadata.csv"
FTC_MAX_FILES = 50


def download_ftc_dataset():
    """
    Download FTC robocall dataset.
    - Saves transcripts from metadata.csv as .txt files (works immediately with --text-only)
    - Also attempts WAV download for full audio pipeline (optional)
    """
    print("\n── FTC Robocall Dataset ──────────────────────────────────────────")
    print("  Fetching metadata...")
    meta_path = DATA_DIR / "ftc_metadata.csv"

    r = requests.get(FTC_META_URL, timeout=30)
    if r.status_code != 200:
        print(f"  ⚠ Could not fetch metadata (HTTP {r.status_code}). Skipping.")
        print("    → Clone manually: https://github.com/wspr-ncsu/robocall-audio-dataset")
        return []

    meta_path.write_bytes(r.content)

    rows = []
    with open(meta_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        print(f"  Columns: {reader.fieldnames}")
        for row in reader:
            rows.append(row)
            if len(rows) >= FTC_MAX_FILES:
                break

    print(f"  Processing {len(rows)} entries...")
    downloaded = []

    import re
    for i, row in enumerate(tqdm(rows, desc="  FTC entries")):
        filename   = row.get("file_name", "").strip()
        transcript = row.get("transcript", "").strip()

        if not filename:
            continue

        # Sanitize filename for Windows (remove :, /, \, *, ?, ", <, >, |)
        safe_name = re.sub(r'[\\/:*?"<>|]', "_", filename)
        if not safe_name.endswith(".wav"):
            safe_name = f"ftc_{i+1:03d}.wav"

        # Save transcript as .txt - works immediately with --text-only, no WAV needed
        txt_dest = SCAM_DIR / safe_name.replace(".wav", ".txt")
        if transcript and not txt_dest.exists():
            txt_dest.write_text(transcript, encoding="utf-8")

        # Optionally download WAV for full audio pipeline
        wav_dest = SCAM_DIR / safe_name
        if not wav_dest.exists():
            try:
                resp = requests.get(f"{FTC_RAW_BASE}/{filename}", timeout=30)
                if resp.status_code == 200:
                    wav_dest.write_bytes(resp.content)
            except Exception:
                pass  # WAV is optional — transcript is sufficient for PoC

        # Prefer WAV if available, fall back to txt
        path = str(wav_dest) if wav_dest.exists() else str(txt_dest)
        downloaded.append({
            "path":       path,
            "label":      "scam",
            "source":     "ftc",
            "transcript": transcript,
            "file_name":  filename,
            "language":   row.get("language", "en"),
        })

    wav_count = sum(1 for d in downloaded if d["path"].endswith(".wav"))
    txt_count = sum(1 for d in downloaded if d["path"].endswith(".txt"))
    print(f"  ✓ {len(downloaded)} scam entries → {wav_count} WAV + {txt_count} transcript-only")
    return downloaded


# ── 2. HuggingFace Scam Dialogue Transcripts (Held-Out Validation Set) ────────
HF_SCAM_LIMIT    = 50   # unseen scam samples
HF_NONSCAM_LIMIT = 50   # unseen safe/non-scam samples

def load_hf_validation_set():
    """
    Load HuggingFace scam-dialogue as a HELD-OUT validation set.
    Never used for pattern tuning — only for unbiased recall/precision testing.

    Dataset fields: dialogue (str), label (0=non-scam, 1=scam), type (scam category)
    """
    print("\n── HuggingFace Validation Set (Held-Out) ─────────────────────────")
    try:
        from datasets import load_dataset
        print("  Loading BothBosu/scam-dialogue...")
        ds = load_dataset("BothBosu/scam-dialogue", split="train", trust_remote_code=True)

        # Peek at structure
        sample = ds[0]
        print(f"  Fields: {list(sample.keys())}")
        print(f"  Sample: label={sample.get('label')}, type={sample.get('type','?')}")
        print(f"  Dialogue preview: {str(sample.get('dialogue',''))[:100]}")

        # Separate scam and non-scam
        scam_items    = [x for x in ds if x.get('label') == 1][:HF_SCAM_LIMIT]
        nonscam_items = [x for x in ds if x.get('label') == 0][:HF_NONSCAM_LIMIT]
        print(f"  Selected: {len(scam_items)} scam + {len(nonscam_items)} non-scam samples")

        # Save raw JSONL for reference
        out_path = DATA_DIR / "hf_validation.jsonl"
        with open(out_path, "w", encoding="utf-8") as f:
            for item in scam_items + nonscam_items:
                f.write(json.dumps(item) + "\n")

        # Build manifest records
        records = []
        for item in scam_items:
            dialogue = item.get("dialogue", "")
            # Extract caller lines only (Suspect turns) for realistic detection
            caller_text = extract_caller_lines(dialogue)
            records.append({
                "path":       "",
                "label":      "scam",
                "source":     "hf_validation",
                "transcript": caller_text,
                "scam_type":  item.get("type", "unknown"),
            })
        for item in nonscam_items:
            dialogue = item.get("dialogue", "")
            caller_text = extract_caller_lines(dialogue)
            records.append({
                "path":       "",
                "label":      "safe",
                "source":     "hf_validation",
                "transcript": caller_text,
                "scam_type":  "non-scam",
            })

        print(f"  ✓ Validation set saved → {out_path}")
        return records

    except Exception as e:
        print(f"  ⚠ Could not load HuggingFace dataset: {e}")
        print(f"    Error: {e}")
        return []


def extract_caller_lines(dialogue: str) -> str:
    """
    Extract only the Suspect/caller lines from a dialogue string.
    Real-world detection only sees the caller, not the victim's responses.
    Falls back to full dialogue if format is not recognized.
    """
    lines = dialogue.split("\n") if isinstance(dialogue, str) else []
    caller_lines = [
        line.replace("Suspect:", "").replace("Caller:", "").strip()
        for line in lines
        if line.strip().startswith(("Suspect:", "Caller:"))
    ]
    if caller_lines:
        return " ".join(caller_lines)
    # Fallback: return full dialogue (some entries may not follow Suspect: format)
    return str(dialogue)[:1000]


# ── 3. Synthetic "Safe Call" Baselines ────────────────────────────────────────
SAFE_CALL_SCRIPTS = [
    "Hi Mom, it's Sarah. Just calling to check in. How are you feeling today?",
    "Hello, this is Dr. Johnson's office calling to confirm your appointment on Thursday at 2pm.",
    "Hey Dad, it's Mike. Are you free for dinner on Sunday? We'd love to have you over.",
    "Hi, this is the pharmacy calling. Your prescription for lisinopril is ready for pickup.",
    "Hello, this is your neighbor Carol. I found your mail in my box by mistake. I'll drop it over.",
    "Hi Grandma, it's Emma. I just wanted to say happy birthday! We're coming to visit next week.",
    "This is a reminder from your dentist office. You have a cleaning scheduled for next Monday.",
    "Hey, it's Dave from next door. Your car lights are on. Thought you'd want to know.",
]

def create_safe_call_transcripts():
    print("\n── Safe Call Baselines ───────────────────────────────────────────")
    safe_records = []
    for i, script in enumerate(SAFE_CALL_SCRIPTS):
        path = SAFE_DIR / f"safe_{i+1:02d}.txt"
        path.write_text(script, encoding="utf-8")
        safe_records.append({
            "path":       str(path),
            "label":      "safe",
            "source":     "synthetic",
            "transcript": script
        })
    print(f"  ✓ Created {len(safe_records)} safe call transcripts → {SAFE_DIR}")
    return safe_records


# ── 4. Save Combined Manifest ──────────────────────────────────────────────────
def save_manifest(scam_records, safe_records, hf_records=None):
    hf_records = hf_records or []

    # ── Tuning manifest (FTC + synthetic) ─────────────────────────────
    tuning_path = DATA_DIR / "manifest.json"
    tuning_files = scam_records + safe_records
    tuning = {
        "total":      len(tuning_files),
        "scam_count": sum(1 for r in tuning_files if r["label"] == "scam"),
        "safe_count": sum(1 for r in tuning_files if r["label"] == "safe"),
        "note":       "Tuning set — patterns were optimized on these samples",
        "files":      tuning_files
    }
    with open(tuning_path, "w", encoding="utf-8") as f:
        json.dump(tuning, f, indent=2)

    # ── Validation manifest (HF held-out) ─────────────────────────────
    val_path = DATA_DIR / "manifest_validation.json"
    val = {
        "total":      len(hf_records),
        "scam_count": sum(1 for r in hf_records if r["label"] == "scam"),
        "safe_count": sum(1 for r in hf_records if r["label"] == "safe"),
        "note":       "Held-out validation set — never used for pattern tuning",
        "files":      hf_records
    }
    with open(val_path, "w", encoding="utf-8") as f:
        json.dump(val, f, indent=2)

    print(f"\n  ✓ Tuning manifest   → {tuning_path} ({tuning['total']} samples)")
    print(f"  ✓ Validation manifest → {val_path} ({val['total']} samples)")
    print(f"\n  Run tuning set  : python run_pipeline.py --text-only --mock-llm")
    print(f"  Run validation  : python run_pipeline.py --text-only --mock-llm --manifest manifest_validation.json")
    return tuning_path


# ── Main ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("  GuardianLine — Dataset Downloader")
    print("=" * 60)

    scam_records  = download_ftc_dataset()
    hf_records    = load_hf_validation_set()
    safe_records  = create_safe_call_transcripts()

    # FTC + synthetic safe = tuning set (what we optimized patterns against)
    # HF validation        = held-out set (never seen during tuning)
    save_manifest(scam_records, safe_records, hf_records)

    print("\n" + "=" * 60)
    print("  Done! Next steps:")
    print("    python run_pipeline.py --text-only --mock-llm   <- instant test")
    print("    python run_pipeline.py --text-only              <- needs Phi-3")
    print("    python run_pipeline.py                          <- full audio")
    print("=" * 60)
