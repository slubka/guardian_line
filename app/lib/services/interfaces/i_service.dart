/// Base service interface for common lifecycle operations.
abstract class IService {
  /// Initialize the service.
  bool init();

  /// Clean up service resources.
  void cleanup();
}
