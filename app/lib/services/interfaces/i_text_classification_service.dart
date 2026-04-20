import 'package:flutter/material.dart';
import 'i_service.dart';
import 'i_transcription_service.dart';

/// Interface for text classification services
abstract class ITextClassificationService implements IService {
  /// Risk score notifier for UI updates
  ValueNotifier<double> get riskScore;
}