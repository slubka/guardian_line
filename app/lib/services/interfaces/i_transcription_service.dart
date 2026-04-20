import 'i_audio_capture_service.dart';
import 'i_service.dart';
import 'i_sliding_window_service.dart';

/// Interface for transcription services
abstract class ITranscriptionService implements IService, ISlidingWindowService<String> {
  /// Check if the service is available/initialized
  Future<bool> isAvailable();
}