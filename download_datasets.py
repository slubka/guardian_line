#!/usr/bin/env python3
"""
download_datasets.py
--------------------
Downloads and prepares audio datasets for GuardianLine pipeline testing.

Sources:
  1. FTC Robocall Audio Dataset (NC State / GitHub) - real robocall WAV files
  2. Scam Dialogue Dataset (HuggingFace) - text transcripts for prompt tuning
  3. Sample "safe" calls - synthesized or public domain normal conversations
"""

import os
import csv
import json
import requests
import zipfile
import io
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
FTC_REPO_API = "https://api.github.com/repos/wspr-ncsu/robocall-audio-dataset/contents/audio"
FTC_RAW_BASE = "https://raw.githubusercontent.com/wspr-ncsu/robocall-audio-dataset/main/audio"
FTC_META_URL = "https://raw.githubusercontent.com/wspr-ncsu/robocall-audio-dataset/main/metadata.csv"
FTC_MAX_FILES = 50  # Limit for PoC — enough to validate without huge download


def download_ftc_dataset():
    """Download real robocall WAV files from the FTC/NC State dataset."""
    print("\n── FTC Robocall Dataset ──────────────────────────────────────────")

    # Download metadata first
    print("  Fetching metadata...")
    meta_path = DATA_DIR / "ftc_metadata.csv"
    r = requests.get(FTC_META_URL, timeout=30)
    if r.status_code != 200:
        print(f"  ⚠ Could not fetch metadata (HTTP {r.status_code}). Skipping FTC dataset.")
        print("    → Try manually cloning: https://github.com/wspr-ncsu/robocall-audio-dataset")
        return []

    meta_path.write_bytes(r.content)
    print(f"  ✓ Metadata saved to {meta_path}")

    # Parse metadata to get file list
    files_to_download = []
    with open(meta_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            files_to_download.append(row)
            if len(files_to_download) >= FTC_MAX_FILES:
                break

    print(f"  Downloading {len(files_to_download)} audio files...")
    downloaded = []
    for row in tqdm(files_to_download, desc="  FTC audio"):
        filename = row.get("filename") or row.get("file") or list(row.values())[0]
        if not filename.endswith(".wav"):
            filename += ".wav"

        dest = SCAM_DIR / filename
        if dest.exists():
            downloaded.append({"path": str(dest), "label": "scam", "source": "ftc", **row})
            continue

        url = f"{FTC_RAW_BASE}/{filename}"
        try:
            r = requests.get(url, timeout=30)
            if r.status_code == 200:
                dest.write_bytes(r.content)
                downloaded.append({"path": str(dest), "label": "scam", "source": "ftc", **row})
        except Exception as e:
            print(f"\n  ⚠ Failed to download {filename}: {e}")

    print(f"  ✓ Downloaded {len(downloaded)} scam audio files → {SCAM_DIR}")
    return downloaded


# ── 2. HuggingFace Scam Dialogue Transcripts ──────────────────────────────────
def download_hf_transcripts():
    """
    Download scam dialogue transcripts from HuggingFace.
    These are text-only — useful for prompt tuning and as ground-truth labels.
    """
    print("\n── HuggingFace Scam Dialogues ────────────────────────────────────")
    try:
        from datasets import load_dataset
        print("  Loading BothBosu/scam-dialogue...")
        ds = load_dataset("BothBosu/scam-dialogue", split="train", trust_remote_code=True)
        out_path = DATA_DIR / "scam_dialogues.jsonl"
        with open(out_path, "w", encoding="utf-8") as f:
            for item in tqdm(ds, desc="  HF transcripts"):
                f.write(json.dumps(item) + "\n")
        print(f"  ✓ Saved {len(ds)} transcripts → {out_path}")
        return str(out_path)
    except Exception as e:
        print(f"  ⚠ Could not load HuggingFace dataset: {e}")
        print("    → Run: pip install datasets")
        return None


# ── 3. Create "Safe Call" Placeholders ────────────────────────────────────────
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
    """Save safe call scripts as text files for baseline testing."""
    print("\n── Safe Call Baselines ───────────────────────────────────────────")
    safe_records = []
    for i, script in enumerate(SAFE_CALL_SCRIPTS):
        path = SAFE_DIR / f"safe_{i+1:02d}.txt"
        path.write_text(script, encoding="utf-8")
        safe_records.append({
            "path": str(path),
            "label": "safe",
            "source": "synthetic",
            "transcript": script
        })
    print(f"  ✓ Created {len(safe_records)} safe call transcripts → {SAFE_DIR}")
    return safe_records


# ── 4. Save Combined Manifest ──────────────────────────────────────────────────
def save_manifest(scam_records, safe_records):
    manifest_path = DATA_DIR / "manifest.json"
    manifest = {
        "total": len(scam_records) + len(safe_records),
        "scam_count": len(scam_records),
        "safe_count": len(safe_records),
        "files": scam_records + safe_records
    }
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"\n  ✓ Manifest saved → {manifest_path}")
    print(f"    Total samples: {manifest['total']} ({manifest['scam_count']} scam, {manifest['safe_count']} safe)")
    return manifest_path


# ── Main ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("  GuardianLine — Dataset Downloader")
    print("=" * 60)

    scam_records = download_ftc_dataset()
    hf_path      = download_hf_transcripts()
    safe_records = create_safe_call_transcripts()

    save_manifest(scam_records, safe_records)

    print("\n" + "=" * 60)
    print("  Done! Next step: run python run_pipeline.py")
    print("=" * 60)
