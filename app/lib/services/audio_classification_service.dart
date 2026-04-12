import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:app/logic/i_classifier.dart';
import 'package:app/logic/local_intent_classifier.dart';

import '../services/audio_capture_service.dart';

class AudioClassificationService {
  final IClassifier _classifier = LocalIntentClassifier();
  
  // We keep the numeric score exposed for fine-grained UI (like a progress bar)
  final ValueNotifier<double> riskScore = ValueNotifier(0.0);
  
  void init(AudioCaptureService captureService) {
    // Register for a 10-second sliding window
    captureService.subscribe(
      const Duration(seconds: 10), 
      (audioWindow) async{
        _analyze(audioWindow);
      }
    );
  }

  void _analyze(Uint8List data) async{
    try {
            final score = await _classifier.analyze(data);
            riskScore.value = max(riskScore.value, score);
            debugPrint("New Risk Score: $score");
          } finally {

          }
  }
}