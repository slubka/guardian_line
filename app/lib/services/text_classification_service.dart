import 'dart:math';
import 'dart:typed_data';
import 'package:app/services/transcription_service.dart';
import 'package:flutter/material.dart';

import 'package:app/logic/i_classifier.dart';
import 'package:app/logic/local_intent_classifier.dart';

import 'interfaces/i_text_classification_service.dart';
import 'interfaces/i_transcription_service.dart';
import 'service_provider.dart';

class TextClassificationService implements ITextClassificationService {
  final IClassifier _classifier = LocalIntentClassifier();
  
  // We keep the numeric score exposed for fine-grained UI (like a progress bar)
  final ValueNotifier<double> riskScore = ValueNotifier(0.0);
  
  void Function(List<Uint8List>)? _windowCallback;

  @override
  bool init() {
    _windowCallback = (data) async {
      _analyze(data);
    };

    ServiceProvider().transcriptionService.subscribe(
      const Duration(seconds: 10),
      _windowCallback!,
    );
    return true;
  }

  @override
  void cleanup() {
    if (_transcriptionService != null && _windowCallback != null) {
      _transcriptionService!.unsubscribe(_windowCallback!);
    }
    _transcriptionService = null;
    _windowCallback = null;
  }

  void _analyze(Uint8List data) async {
    try {
      final score = await _classifier.analyze(data);
      riskScore.value = max(riskScore.value, score);
      debugPrint("New Risk Score: $score");
    } finally {
      // No cleanup needed here
    }
  }
}