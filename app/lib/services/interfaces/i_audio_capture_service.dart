import 'dart:typed_data';

import 'i_service.dart';
import 'i_sliding_window_service.dart';

/// Interface for audio capture services
abstract class IAudioCaptureService implements IService, ISlidingWindowService<Uint8List> {
  /// Start audio capture
  Future<void> startCapture();

  /// Get current buffer statistics
  Map<String, dynamic> getStats();
}