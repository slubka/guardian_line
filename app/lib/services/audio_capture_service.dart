import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

class AudioSubscription {
  final Duration window;
  final void Function(Uint8List) onData;

  AudioSubscription({required this.window, required this.onData});
}

class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStream;
  
  // Master buffer of raw bytes
  final List<int> _buffer = [];
  
  // Audio configuration constants
  static const int sampleRate = 16000;
  static const int bytesPerSample = 2; // 16-bit PCM

  // List of generic subscribers
  final List<AudioSubscription> _subscribers = [];

  /// Registers a callback to receive a sliding window of audio data.
  void subscribe(Duration window, void Function(Uint8List) onData) {
    _subscribers.add(AudioSubscription(window: window, onData: onData));
  }

  Future<void> startCapture() async {
    if (await _recorder.hasPermission()) {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      final stream = await _recorder.startStream(config);
      
      _audioStream = stream.listen((Uint8List chunk) {
        _buffer.addAll(chunk);
        _notifySubscribers();
        _truncateBuffer();
      });
    }
  }

  void _notifySubscribers() {
    for (var sub in _subscribers) {
      int requiredBytes = _getByteCountForDuration(sub.window);

      if (_buffer.length >= requiredBytes) {
        // Create a view of the last N bytes
        final windowData = Uint8List.fromList(
          _buffer.sublist(_buffer.length - requiredBytes)
        );
        sub.onData(windowData);
      }
    }
  }

  void _truncateBuffer() {
    // Keep only the amount of data required by the longest subscription
    // + a small safety margin (e.g., 1 minute)
    Duration maxWindow = _subscribers.isEmpty 
        ? Duration.zero
        : _subscribers.map((s) => s.window).reduce((a, b) => a > b ? a : b);
    
    // add safety margin of 60 milliseconds to account for any timing discrepancies
    int retentionBytes = _getByteCountForDuration(maxWindow + Duration(milliseconds: 60));

    if (_buffer.length > retentionBytes) {
      _buffer.removeRange(0, _buffer.length - retentionBytes);
    }
  }

  void stop() {
    _audioStream?.cancel();
    _recorder.dispose();
    _buffer.clear();
  }

  int _getByteCountForDuration(Duration duration) {
    // Bytes = (Seconds * Samples/Second * Bytes/Sample)
    // We use inMicroseconds for higher precision with very short durations
    return (duration.inMicroseconds / 1000000 * sampleRate * bytesPerSample).toInt();
  }
}