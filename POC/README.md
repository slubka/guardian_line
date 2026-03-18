# Pipeline Test

This folder validates the core GuardianLine hypothesis:

> **"Can we detect a scam call in under 15 seconds with acceptable accuracy?"**

The pipeline runs: **Audio → Whisper STT → Phi-3 Mini → Risk Score → Traffic Light**

---

## Quick Start (5 minutes)

### Step 1 — Install dependencies

**Python 3.13 on Windows (run in order):**
```bash
python -m pip install --upgrade pip setuptools
pip install -r requirements.txt
```

**If `llama-cpp-python` fails on Windows**, use the pre-built CPU wheel:
```bash
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu
```

### Step 2 — Download datasets
```bash
python download_datasets.py
```
Downloads ~50 real FTC robocall WAV files + creates safe call baselines.

### Step 3 — Test immediately (no model download needed)
```bash
python run_pipeline.py --text-only --mock-llm
```
Uses rule-based keyword detection on text transcripts. Runs in seconds, no GPU needed.

### Step 4 — Download Phi-3 Mini (~2.4 GB, one-time)
```bash
python download_model.py
```

### Step 5 — Run full pipeline with real LLM
```bash
python run_pipeline.py --text-only   # transcripts + Phi-3
python run_pipeline.py               # full audio + Whisper + Phi-3
```

---

## Flags

| Flag | Description |
|------|-------------|
| `--limit N` | Only process N samples (e.g. `--limit 10` for a quick test) |
| `--text-only` | Skip Whisper, use .txt transcripts directly |
| `--mock-llm` | Use keyword-based mock instead of Phi-3 Mini |

---

## What We're Measuring

| Metric | Target | Why |
|--------|--------|-----|
| **Recall** (scam catch rate) | >85% | Missing a scam is the worst outcome |
| **Precision** (false alarm rate) | >80% | Too many false alarms = user ignores warnings |
| **Total latency** | <10s | Must warn before scammer establishes trust |
| **LLM latency alone** | <8s | Leaves 2s buffer for Whisper on device |

---

## Output

Results are saved to `results/`:
- `results_TIMESTAMP.csv` — per-sample breakdown
- `summary_TIMESTAMP.json` — aggregate metrics (accuracy, F1, latency)

---

## Directory Structure

```
pipeline_test/
├── download_datasets.py   # Fetches FTC + HuggingFace data
├── download_model.py      # Downloads Phi-3 Mini GGUF
├── run_pipeline.py        # Main benchmark runner
├── requirements.txt
├── data/
│   ├── scam/              # FTC robocall WAV files
│   ├── safe/              # Synthetic safe call transcripts
│   ├── scam_dialogues.jsonl  # HuggingFace transcripts
│   └── manifest.json      # Index of all samples
├── models/
│   └── phi-3-mini-4k-instruct.Q4_K_M.gguf
└── results/
    ├── results_*.csv
    └── summary_*.json
```
