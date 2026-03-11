# GuardianLine

> Restoring trust in the telephone by neutralizing AI-driven social engineering at the point of contact.

## What is GuardianLine?

GuardianLine is a real-time, AI-powered "Guardian-in-the-Middle." Unlike binary call blockers (block/allow), it provides **Active Assistance** — analyzing caller intent in the first 15 seconds to detect "The Hook" before "The Harvest" begins.

---

## Repository Structure

```
guardian_line/
├── pipeline_test/       ← START HERE — validates core detection accuracy & latency
├── app/                 ← Flutter mobile app (Phase 2)
├── backend/             ← Firebase/AWS alerting backend (Phase 2)
└── docs/                ← Architecture & strategy documents
```

---

## Phase 1: Pipeline Validation (Current Focus)

Before building the app, we validate the core hypothesis:

> **"Can we detect a scam call in under 15 seconds with acceptable accuracy?"**

### Setup

```bash
cd pipeline_test
pip install -r requirements.txt
```