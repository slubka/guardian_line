import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'sliding_window_service.dart';
import 'interfaces/i_audio_capture_service.dart';

class AudioCaptureService extends SlidingWindowService<Uint8List> implements IAudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStream;

  // Audio configuration constants
  static const int sampleRate = 16000;
  static const int bytesPerSample = 2; // 16-bit PCM

  AudioCaptureService() : super(trackTimestamps: true);

  @override
  bool init() {
    return true;
  }

  /// Starts audio capture and feeds recorder chunks into the sliding window.
  Future<void> startCapture() async {
    if (await _recorder.hasPermission()) {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      final stream = await _recorder.startStream(config);
      _audioStream = stream.listen((Uint8List chunk) {
        addData(chunk);
      });
    }
  }

  @override
  void cleanup() {
    _audioStream?.cancel();
    _recorder.dispose();
    clear();
  }

  void stop() {
    _audioStream?.cancel();
    _recorder.dispose();
    clear();
  }

  /// Gets current buffer statistics
  Map<String, dynamic> getStats() {
    return {
      'audioBufferSize': bufferSize,
      'subscriberCount': subscribers.length,
      'sampleRate': sampleRate,
      'bytesPerSample': bytesPerSample,
    };
  }
}
