/// Generic sliding window subscription
class SlidingWindowSubscription<T> {
  final Duration window;
  final void Function(List<T>) onData;

  SlidingWindowSubscription({required this.window, required this.onData});
}

/// Interface for sliding window services that manage data buffering and subscriptions
abstract class ISlidingWindowService<T> {
  /// Registers a callback to receive a sliding window of data
  void subscribe(Duration window, void Function(List<T>) onData);

  /// Unsubscribes a specific callback
  void unsubscribe(void Function(List<T>) onData);

  /// Adds new data to the buffer and notifies subscribers
  void addData(T data);
}