import 'dart:typed_data';

import '../services/audio_capture_service.dart';

class AudioClassificationService {
  void init(AudioCaptureService captureService) {
    // Register for a 10-second sliding window
    captureService.subscribe(
      const Duration(seconds: 10), 
      (audioWindow) {
        _analyze(audioWindow);
      }
    );
  }

  void _analyze(Uint8List data) {
    // This is where your TFLite/ONNX model will live
    // data is exactly 10 seconds of PCM audio
    print("Analyzing window of size: ${data.length} bytes");
  }
}