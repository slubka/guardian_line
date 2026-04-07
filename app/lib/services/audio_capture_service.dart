import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioCaptureService {
  final List<Uint8List> _buffer = [];
  int _totalBytesReceived = 0;
  int _chunkCount = 0;

  static const int _maxBufferBytes = 480000;
  bool _isCapturing = false;

  // UI callback — call_screen uses this to update the chunk counter
  void Function(int chunkCount)? onChunkReceived;

  void attachToTrack(MediaStreamTrack track) {
    if (_isCapturing) return;
    _isCapturing = true;
    debugPrint('[AudioCapture] Attached to remote track: ${track.id}');

    // Poll the buffer snapshot periodically instead of onAudioData
    _startPolling(track);
  }

  void _startPolling(MediaStreamTrack track) async {
    while (_isCapturing) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (!_isCapturing) break;

      // Simulate PCM chunk receipt — in Phase 2 this becomes real Whisper input
      final fakeChunk = Uint8List(320); // 20ms of silence at 16kHz 16-bit mono
      _onPcmChunk(fakeChunk);
    }
  }

  void _onPcmChunk(Uint8List chunk) {
    _chunkCount++;
    _totalBytesReceived += chunk.lengthInBytes;

    _buffer.add(chunk);

    int bufferSize = _buffer.fold(0, (sum, c) => sum + c.lengthInBytes);
    while (bufferSize > _maxBufferBytes && _buffer.isNotEmpty) {
      bufferSize -= _buffer.removeAt(0).lengthInBytes;
    }

    if (_chunkCount % 100 == 0) {
      debugPrint(
        '[AudioCapture] ✅ Chunks: $_chunkCount | '
        'Total bytes: $_totalBytesReceived | '
        'Buffer: ${_buffer.length} chunks',
      );
    }

    onChunkReceived?.call(_chunkCount);
  }

  Uint8List getBufferSnapshot() {
    final total = _buffer.fold(0, (sum, c) => sum + c.lengthInBytes);
    final result = Uint8List(total);
    int offset = 0;
    for (final chunk in _buffer) {
      result.setRange(offset, offset + chunk.lengthInBytes, chunk);
      offset += chunk.lengthInBytes;
    }
    return result;
  }

  void dispose() {
    _isCapturing = false;
    _buffer.clear();
    debugPrint('[AudioCapture] Disposed. Total chunks: $_chunkCount');
  }
}