import 'dart:typed_data';

abstract class IClassifier {
  /// Analyzes raw PCM data and returns a risk score from 0.0 to 1.0.
  /// 0.0 = Completely Safe/White
  /// 1.0 = Critical Danger/Red
  Future<double> analyze(Uint8List audioData);
  
  /// Helper to convert enum to human readable strings or colors if needed
  String get name;
}