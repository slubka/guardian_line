#!/usr/bin/env python3
"""
download_model.py
-----------------
Downloads the Phi-3 Mini GGUF model for local inference.
Model: microsoft/Phi-3-mini-4k-instruct-gguf (Q4_K_M quantized, ~2.4GB)

This is a one-time setup step.
"""

import os
from pathlib import Path

MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)

MODEL_REPO = "microsoft/Phi-3-mini-4k-instruct-gguf"
MODEL_FILE = "Phi-3-mini-4k-instruct-q4.gguf"
DEST_NAME  = "phi-3-mini-4k-instruct.Q4_K_M.gguf"  # Expected by run_pipeline.py


def download_phi3():
    dest = MODELS_DIR / DEST_NAME
    if dest.exists():
        print(f"✓ Model already exists at {dest}")
        print(f"  Size: {dest.stat().st_size / 1e9:.2f} GB")
        return

    print(f"Downloading Phi-3 Mini from HuggingFace...")
    print(f"  Repo : {MODEL_REPO}")
    print(f"  File : {MODEL_FILE}")
    print(f"  Dest : {dest}")
    print(f"  Size : ~2.4 GB — this will take a few minutes\n")

    try:
        from huggingface_hub import hf_hub_download
        path = hf_hub_download(
            repo_id   = MODEL_REPO,
            filename  = MODEL_FILE,
            local_dir = str(MODELS_DIR),
        )
        # Rename to expected filename
        Path(path).rename(dest)
        print(f"\n✓ Model downloaded → {dest}")
        print(f"  Size: {dest.stat().st_size / 1e9:.2f} GB")

    except ImportError:
        print("ERROR: huggingface_hub not installed.")
        print("  Run: pip install huggingface_hub")
    except Exception as e:
        print(f"ERROR: {e}")
        print("\nManual download:")
        print(f"  1. Visit: https://huggingface.co/{MODEL_REPO}")
        print(f"  2. Download: {MODEL_FILE}")
        print(f"  3. Save to: {dest}")


if __name__ == "__main__":
    download_phi3()
    print("\nNext step: python run_pipeline.py --mock-llm   (test without model)")
    print("       or: python run_pipeline.py              (full Phi-3 inference)")
