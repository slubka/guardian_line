# GuardianLine — STATE.md
# Single source of truth. Read at session start. Update before closing.

## Last Updated
2026-04-12

## Project Status
- Engineering: Python benchmark pipeline complete (98% accuracy). Flutter shell running
  on Android emulator. Phase 1 (audio capture) implementation ready to apply.
- Business: Strategy doc complete. All GTM/fundraising questions open.
- **Pipeline Ready:** The internal audio pipeline is fully functional. Raw PCM data flows from the `AudioCaptureService` directly to the `AudioClassificationService` once a connection is established.
- **Trigger Logic:** Classification activation is now strictly tied to the **Callee** role. The system waits for an incoming `RTCTrackEvent` before engaging the analysis engine, ensuring we only "guard" active incoming streams.
- **Simulation Harness:** Implemented a local loopback mechanism within `CallScreen`. The "Simulate Incoming Call" button allows for end-to-end testing of the audio buffer and classification triggers on a single device without an external signaling server.


## Open Questions
- [ ] BLOCKER: Which geographic market first — US, UK, or EU? → Owner: Product Strategist
- [ ] BLOCKER: Cost-of-fraud per senior for a mid-tier bank → Owner: Product Strategist
- [ ] BLOCKER: Specific raise amount for pitch deck Ask slide → Owner: Product Strategist
- [ ] BLOCKER: On-device latency on iPhone 12 — is 2-5s achievable with Neural Engine? → Owner: Architect (parked until real device available)
- [ ] BLOCKER: Two-party consent legal requirements per target region → Owner: Architect
- [ ] BLOCKER: Production call routing must use PSTN bridge (Twilio or equivalent).
      Pure WebRTC VoIP-to-VoIP model is disqualified — requires caller-side setup.
      Need to evaluate Twilio vs alternatives (cost, privacy, latency, BAA availability)
      → Owner: Architect + Product Strategist
- [ ] NICE-TO-HAVE: Name and story for the 'Sandwich Generation' buyer persona → Owner: Product Strategist
- [ ] NICE-TO-HAVE: Free tier strategy — basic caller ID to build user base? → Owner: Product Strategist
- [ ] NICE-TO-HAVE: 2-3 key competitors to feature in pitch deck → Owner: Product Strategist
- [ ] NICE-TO-HAVE: Medical bypass design — voice-activated Digital Butler? → Owner: Architect + Product Strategist
- [ ] NICE-TO-HAVE: Risk score threshold that triggers family notification → Owner: Architect + Product Strategist
- [ ] NICE-TO-HAVE: Evaluate Option C (pre-call screening / challenge model) as
      privacy-preserving alternative to live audio interception → Owner: Architect + Product Strategist

## Decision Log
- **[2026-04-12] Callee-Centric Analysis:** Decided to shift the classification trigger to the receiving side of the call to focus on protecting the user from incoming threats ("The Hook").
- **[2026-04-12] Internal Loopback for Development:** Adopted a dual-PeerConnection approach in the same memory space. This bypasses signaling complexity during the current benchmarking phase and enables rapid local iteration.
- **[2026-04-12] Persistent Variable Naming:** Maintained `_audioClassification` and `AudioClassificationService` naming conventions to ensure consistency with the established POC structure and Git history.
- 2026-03-19 | Flutter + flutter_webrtc chosen as cross-platform app framework
  Rationale: fastest PoC dev, single codebase for iOS + Android | Owner: Architect
- 2026-03-19 | Whisper.cpp chosen for on-device STT
  Rationale: privacy-first, no audio leaves device | Owner: Architect
- 2026-03-19 | Phi-3 Mini chosen as on-device SLM
  Rationale: matched mock classifier accuracy (96% recall, 100% precision) | Owner: Architect
- 2026-03-19 | Two-tier pattern classifier as fast baseline before LLM
  Rationale: 98% accuracy on held-out set; LLM adds value for novel scripts only | Owner: Architect
- 2026-03-19 | STATE.md in GitHub chosen as shared state mechanism
  Rationale: version history, lives with code, compatible with future GitHub MCP integration | Owner: Orchestrator
- 2026-03-22 | HARD CONSTRAINT: Zero installation or configuration required on caller side.
  Any architecture that requires the caller to install an app, use a special number,
  or change their behavior in any way is disqualified.
  Rationale: Scammers will never comply. Legitimate callers shouldn't have to.
  Implication: Pure WebRTC VoIP-to-VoIP model is off the table for production.
  Production must use a PSTN bridge (Twilio or equivalent) so callers dial normally.
  Owner: Orchestrator
- 2026-03-22 | PoC loopback model unaffected by caller-side constraint.
  Rationale: Loopback is internal to device only — validates detection pipeline,
  not call routing. PSTN bridge decision deferred to post-PoC. | Owner: Architect

## Handoff Queue
- Pending: Architect + Product Strategist
  Task: Evaluate PSTN bridge options for production (Twilio vs alternatives)
  Context: Hard constraint established — zero caller-side installation. Production
  routing must bridge PSTN → WebRTC on GuardianLine's side only. Evaluate:
  cost per minute, privacy policy / BAA availability, latency impact on detection,
  regulatory compliance per target region.
  Blocker: yes — blocks production architecture definition

- Pending: Architect
  Task: Validate on-device inference latency on iPhone 12 or mid-range Android
  Context: Phi-3 Mini showed 23.7s on Windows CPU; target is 2-5s on Neural Engine
  Blocker: parked — cannot proceed until real device available

- Pending: Product Strategist
  Task: Research cost-of-fraud per senior for mid-tier bank
  Context: Needed for Slide 7 of pitch deck and B2B enterprise pitch
  Blocker: yes

- Pending: Product Strategist
  Task: Determine priority geographic market (US / UK / EU)
  Context: Affects regulatory strategy, GTM focus, and partnership targets
  Blocker: yes — blocks GTM planning
- **Performance Budget:** How long does the local classification of a 10–15s window take? We need to determine if the processing time necessitates moving the service to a background Isolate to maintain 60fps UI performance.
- **Data Normalization:** Does the local model require raw 16-bit PCM, or must we implement a conversion layer to `Float32` (-1.0 to 1.0) before passing the buffer to the classifier?
- **Android 15 Concurrency:** Will the `record` package maintain stable access to the microphone hardware while a WebRTC high-priority audio session is active on all target physical devices?


## Milestone Tracker
- [x] Python benchmark pipeline — 98% accuracy, precision, recall (held-out validation n=100)
- [x] Phi-3 Mini integration — 96% recall, 100% precision, matched mock classifier
- [x] WebRTC architecture review — loopback model selected for PoC
- [x] Hard constraint defined — zero caller-side installation requirement
- [ ] Apply Phase 1 code — flutter_webrtc + AudioSink on Android emulator
- [ ] Confirm PCM chunks flowing (chunk counter > 0 in UI)
- [ ] Device latency test — iPhone 12 or mid-range Android, confirm 2-5s target
- [ ] Whisper STT benchmark on real audio — FTC dataset WAV files
- [ ] Caller-only stream validation — re-run HuggingFace set with caller lines only
- [ ] Flutter app — Phase 2: Whisper STT + Phi-3 Mini inference + Risk Score 0-10
- [ ] Flutter app — Phase 3: Safety Traffic Light UI + Firebase family alert
- [ ] PSTN bridge evaluation — Twilio vs alternatives