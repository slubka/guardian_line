import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/service_provider.dart';
import 'i_classifier.dart';
import 'package:llamadart/llamadart.dart'; // LLM Engine
import '../services/transcription_service.dart';

class LocalIntentClassifier implements IClassifier {
  @override
  String get name => "Local Intent Classifier (Phase 1)";

  LlamaEngine? _phi3Engine;

  LocalIntentClassifier() {
    _initializeEngines();
  }

  Future<void> _initializeEngines() async {
    try {
      // Initialize Phi-3 LLM
      final backend = LlamaBackend();
      _phi3Engine = LlamaEngine(backend);
    } catch (e) {
      debugPrint("Failed to initialize engines: $e");
    }
  }

  @override
  Future<double> analyze(Uint8List audioData) async {
    // For now, run synchronously to avoid isolate complexity
    // TODO: Refactor to use isolates properly with engine instances
    return await _processAudio(audioData);
  }

  Future<double> _processAudio(Uint8List data) async {
    // These can run in parallel in separate Isolates
    final semanticScore = await _getSemanticScore(data); // The "What" (Phi-3)
    final acousticScore = await _getAcousticScore(data); // The "How" (Intonation)

    // Weighted average: e.g., 70% Logic, 30% Emotion
    // In the future, you can raise the weight of acousticScore
    return (semanticScore * 0.7) + (acousticScore * 0.3);
  }

  Future<double> _getSemanticScore(Uint8List audioData) async {
    try {
      // 1. Transcribe audio using the transcription service
      final String transcript = await ServiceProvider().transcriptionService.transcribe(audioData);

      if (transcript.isEmpty || transcript.length < 10) {
        return 0.0; // Not enough context to judge
      }

      // 2. Analyze the text with Phi-3 (via llama.cpp)
      final String prompt = _buildScamAnalysisPrompt(transcript);
      final StringBuffer responseBuffer = StringBuffer();
      await for (final chunk in _phi3Engine!.generate(prompt)) {
        responseBuffer.write(chunk);
      }
      final String llmResponse = responseBuffer.toString();

      // 3. Extract the numeric score from the LLM's string output
      return _parseScore(llmResponse);
    } catch (e) {
      debugPrint("Semantic Analysis Error: $e");
      return 0.0;
    }
  }

  Future<double> _getAcousticScore(Uint8List audioData) async {
    // This is where you'd run a tiny TFLite model that looks for 
    // high-pitch 'Urgency' or 'Aggressive' frequencies.
    // It works on ANY phone because TFLite is extremely legacy-friendly.
    return 0.2; 
  }

  String _buildScamAnalysisPrompt(String transcript) {
    return '''
Analyze this phone call transcript for potential scam indicators. Rate the likelihood that this is a scam call on a scale from 0.0 to 1.0, where:
- 0.0 = Definitely legitimate
- 0.5 = Uncertain/Neutral  
- 1.0 = Definitely a scam

Consider these scam indicators:
- Pressure to act immediately
- Requests for money or personal information
- Unsolicited offers of help or prizes
- Threats or urgent warnings
- Caller claims to be from government/authority
- Technical support scams
- Investment or lottery scams

Transcript: "$transcript"

Respond with ONLY a number between 0.0 and 1.0 representing your confidence this is a scam.
''';
  }

  double _parseScore(String llmResponse) {
    try {
      // Extract numeric score from LLM response
      final RegExp scoreRegex = RegExp(r'(\d+\.?\d*)');
      final match = scoreRegex.firstMatch(llmResponse);
      if (match != null) {
        final score = double.parse(match.group(1)!);
        return score.clamp(0.0, 1.0); // Ensure score is between 0 and 1
      }
    } catch (e) {
      debugPrint("Failed to parse score from LLM response: $e");
    }
    return 0.5; // Default neutral score if parsing fails
  }
}