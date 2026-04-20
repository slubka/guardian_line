import 'package:app/services/audio_capture_service.dart';
import 'package:app/services/text_classification_service.dart';
import 'package:app/services/transcription_service.dart';
import 'interfaces/i_audio_capture_service.dart';
import 'interfaces/i_text_classification_service.dart';
import 'interfaces/i_transcription_service.dart';

/// Service provider for managing service instances and dependencies
///
/// Provides a centralized way to initialize and access services throughout the app.
/// Follows the singleton pattern to ensure consistent service instances.
class ServiceProvider {
  // Singleton instance
  static final ServiceProvider _instance = ServiceProvider._internal();
  factory ServiceProvider() => _instance;
  ServiceProvider._internal();

  // Service instances
  IAudioCaptureService _audioCaptureService = AudioCaptureService();
  ITranscriptionService _transcriptionService = TranscriptionService();
  ITextClassificationService _textClassificationService = TextClassificationService();

  // Initialization state
  bool _servicesInitialized = false;

  // Getters for services
  IAudioCaptureService get audioCaptureService {
    return _audioCaptureService;
  }

  ITranscriptionService get transcriptionService {
    return _transcriptionService;
  }

  ITextClassificationService get textClassificationService {
    return _textClassificationService;
  }

  /// Initialize all services with their dependencies
  bool initializeServices() {
    try {
      // Initialize audio capture service first
      bool audioInitialized = _audioCaptureService.init();
      if (!audioInitialized) {
        print('Failed to initialize audio capture service');
        return false;
      }

      // Initialize transcription service with audio capture dependency
      bool transcriptionInitialized = _transcriptionService.init();
      if (!transcriptionInitialized) {
        print('Failed to initialize transcription service');
        return false;
      }

      // Initialize text classification service with transcription dependency
      bool classificationInitialized = _textClassificationService.init();
      if (!classificationInitialized) {
        print('Failed to initialize text classification service');
        return false;
      }

      _servicesInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing services: $e');
      return false;
    }
  }

  /// Dispose all services
  void cleanup() {
    _transcriptionService.cleanup();
    _audioCaptureService.cleanup();
    _textClassificationService.cleanup();
    _servicesInitialized = false;
  }

  /// Check if all services are initialized
  bool get isInitialized => _servicesInitialized;
}