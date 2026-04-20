import 'dart:async';
import 'dart:collection';
import 'interfaces/i_sliding_window_service.dart';

/// Generic sliding window service for buffering and distributing data streams
class SlidingWindowService<T> implements ISlidingWindowService<T> {
  // Master buffer of data items
  final Queue<T> _buffer = Queue<T>();

  // List of subscribers with their window requirements
  final List<SlidingWindowSubscription<T>> _subscribers = [];

  // Timestamp tracking for data items (if temporal ordering matters)
  final List<DateTime> _timestamps = [];
  final bool _trackTimestamps;

  SlidingWindowService({bool trackTimestamps = false}) : _trackTimestamps = trackTimestamps;

  /// Registers a callback to receive a sliding window of data.
  /// The callback will be invoked whenever there's enough data to fill the specified window.
  void subscribe(Duration window, void Function(List<T>) onData) {
    _subscribers.add(SlidingWindowSubscription(window: window, onData: onData));
  }

  /// Unsubscribes a specific callback
  void unsubscribe(void Function(List<T>) onData) {
    _subscribers.removeWhere((sub) => sub.onData == onData);
  }

  /// Adds new data to the buffer and notifies subscribers if windows are filled
  void addData(T data) {
    _buffer.add(data);
    if (_trackTimestamps) {
      _timestamps.add(DateTime.now());
    }

    _notifySubscribers();
    _truncateBuffer();
  }

  /// Clears all buffered data
  void clear() {
    _buffer.clear();
    _timestamps.clear();
  }

  /// Gets the current buffer size
  int get bufferSize => _buffer.length;

  /// Gets all current subscribers
  List<SlidingWindowSubscription<T>> get subscribers => List.unmodifiable(_subscribers);

  void _notifySubscribers() {
    if (_subscribers.isEmpty) return;

    for (final sub in _subscribers) {
      final windowData = _getWindowData(sub.window);
      if (windowData.isNotEmpty) {
        sub.onData(windowData);
      }
    }
  }

  List<T> _getWindowData(Duration window) {
    if (_buffer.isEmpty) return [];

    if (_trackTimestamps && _timestamps.length == _buffer.length) {
      // Time-based windowing
      final cutoffTime = DateTime.now().subtract(window);
      final startIndex = _timestamps.indexWhere((timestamp) => timestamp.isAfter(cutoffTime));

      if (startIndex == -1) {
        // All data is within the window
        return List.from(_buffer);
      } else if (startIndex < _buffer.length) {
        // Return data from startIndex to end
        return List.from(_buffer.skip(startIndex));
      }
    } else {
      // Count-based windowing (estimate based on time)
      // This is a simple approximation - in practice, you'd want proper timing
      final estimatedItemCount = _estimateItemCountForDuration(window);
      if (_buffer.length >= estimatedItemCount) {
        return List.from(_buffer.take(estimatedItemCount));
      }
    }

    return [];
  }

  void _truncateBuffer() {
    if (_subscribers.isEmpty) return;

    // Find the maximum window duration
    Duration maxWindow = _subscribers
        .map((s) => s.window)
        .reduce((a, b) => a > b ? a : b);

    if (_trackTimestamps && _timestamps.isNotEmpty) {
      // Time-based truncation
      final cutoffTime = DateTime.now().subtract(maxWindow);
      final keepFromIndex = _timestamps.indexWhere((timestamp) => timestamp.isAfter(cutoffTime));

      if (keepFromIndex > 0) {
        // Remove old data
        for (int i = 0; i < keepFromIndex; i++) {
          _buffer.removeFirst();
          _timestamps.removeAt(0);
        }
      }
    } else {
      // Count-based truncation with safety margin
      final maxItems = _estimateItemCountForDuration(maxWindow) * 2; // 2x safety margin

      if (_buffer.length > maxItems) {
        final removeCount = _buffer.length - maxItems;
        for (int i = 0; i < removeCount; i++) {
          _buffer.removeFirst();
        }
        if (_trackTimestamps) {
          _timestamps.removeRange(0, removeCount);
        }
      }
    }
  }

  /// Estimates how many items fit in a given duration
  /// This is a rough approximation - override for more accurate calculations
  int _estimateItemCountForDuration(Duration duration) {
    // Default: assume 10 items per second
    // Subclasses should override this with actual timing data
    return (duration.inMilliseconds / 100).round();
  }

  /// Gets a snapshot of current buffer contents
  List<T> getBufferSnapshot() {
    return List.from(_buffer);
  }

  /// Gets buffer statistics
  Map<String, dynamic> getStats() {
    return {
      'bufferSize': _buffer.length,
      'subscriberCount': _subscribers.length,
      'windows': _subscribers.map((s) => s.window.inMilliseconds).toList(),
      'trackingTimestamps': _trackTimestamps,
    };
  }
}