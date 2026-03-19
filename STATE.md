# GuardianLine — STATE.md
# Single source of truth. Read at session start. Update before closing.

## Last Updated
2026-03-19 | Session: Initial state setup

## Project Status
- Engineering: Python benchmark pipeline complete (98% accuracy). Flutter app not started.
- Business: Strategy doc complete. All GTM/fundraising questions open — no market or persona decisions made yet.
- Last completed: Agents doc updated to v2.0 — Product Strategist added, STATE.md handoff protocol defined.

## Open Questions
- [ ] BLOCKER: Which geographic market first — US, UK, or EU? → Owner: Product Strategist
- [ ] BLOCKER: Cost-of-fraud per senior for a mid-tier bank → Owner: Product Strategist
- [ ] BLOCKER: Specific raise amount for pitch deck Ask slide → Owner: Product Strategist
- [ ] BLOCKER: On-device latency on iPhone 12 — is 2-5s achievable with Neural Engine? → Owner: Architect
- [ ] BLOCKER: Two-party consent legal requirements per target region → Owner: Architect
- [ ] NICE-TO-HAVE: Name and story for the 'Sandwich Generation' buyer persona → Owner: Product Strategist
- [ ] NICE-TO-HAVE: Free tier strategy — basic caller ID to build user base? → Owner: Product Strategist
- [ ] NICE-TO-HAVE: 2-3 key competitors to feature in pitch deck → Owner: Product Strategist
- [ ] NICE-TO-HAVE: Medical bypass design — voice-activated Digital Butler? → Owner: Architect + Product Strategist
- [ ] NICE-TO-HAVE: Risk score threshold that triggers family notification → Owner: Architect + Product Strategist

## Decision Log
- 2026-03-19 Flutter + flutter_webrtc chosen as cross-platform app framework | Rationale: fastest PoC dev, single codebase for iOS + Android | Owner: Architect
- 2026-03-19 Whisper.cpp chosen for on-device STT | Rationale: privacy-first, no audio leaves device | Owner: Architect
- 2026-03-19 Phi-3 Mini chosen as on-device SLM | Rationale: matched mock classifier accuracy (96% recall, 100% precision) at acceptable size | Owner: Architect
- 2026-03-19 Two-tier pattern classifier as fast baseline before LLM | Rationale: 98% accuracy on held-out set; LLM adds value for novel scripts only | Owner: Architect
- 2026-03-19 STATE.md in GitHub chosen as shared state mechanism | Rationale: version history, lives with code, compatible with future GitHub MCP integration | Owner: Orchestrator

## Handoff Queue
- Pending: Architect → Task: validate on-device inference latency on iPhone 12 or mid-range Android
  Context: Phi-3 Mini showed 23.7s on Windows CPU dev machine; target is 2-5s on Neural Engine
  Blocker: yes — Flutter Phase 2 cannot start until latency is confirmed

- Pending: Product Strategist → Task: research cost-of-fraud per senior for mid-tier bank
  Context: needed for Slide 7 of pitch deck and B2B enterprise pitch; flagged as fundraising blocker
  Blocker: yes

- Pending: Product Strategist → Task: determine priority geographic market (US / UK / EU)
  Context: affects regulatory strategy, GTM focus, and partnership targets
  Blocker: yes — blocks GTM planning

## Milestone Tracker
- [x] Python benchmark pipeline — 98% accuracy, precision, recall (held-out validation n=100)
- [x] Phi-3 Mini integration — 96% recall, 100% precision, matched mock classifier
- [ ] Device latency test — iPhone 12 or mid-range Android, confirm 2-5s target
- [ ] Whisper STT benchmark on real audio — FTC dataset WAV files
- [ ] Caller-only stream validation — re-run HuggingFace set with caller lines only
- [ ] Flutter app — Phase 1: WebRTC dual-stream audio capture with AudioSink
- [ ] Flutter app — Phase 2: Whisper STT + Phi-3 Mini inference + Risk Score 0-10
- [ ] Flutter app — Phase 3: Safety Traffic Light UI + Firebase family alert
