import 'dart:async';
import 'dart:collection';

/// Operation queue for processing image edits without blocking UI.
/// Allows UI to remain fully responsive while operations are queued and processed asynchronously.
class OperationQueue {
  final Queue<_Operation> _queue = Queue();
  bool _isProcessing = false;
  final List<Function()> _listeners = [];

  /// Add a listener for operation state changes.
  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  /// Remove a listener.
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of state change.
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Enqueue an operation without blocking.
  Future<T> enqueue<T>(
    Future<T> Function() operation, {
    String? label,
  }) async {
    final completer = Completer<T>();
    _queue.add(_Operation(
      operation: () async {
        try {
          final result = await operation();
          completer.complete(result);
          return result;
        } catch (e) {
          completer.completeError(e);
          rethrow;
        }
      },
      label: label,
    ));

    _notifyListeners();
    _processQueue();

    return completer.future;
  }

  /// Process the queue sequentially.
  Future<void> _processQueue() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    _notifyListeners();

    while (_queue.isNotEmpty) {
      final op = _queue.removeFirst();
      try {
        await op.operation();
      } catch (e) {
        // Log error but continue processing queue
      }
      _notifyListeners();
    }

    _isProcessing = false;
    _notifyListeners();
  }

  /// Check if queue is currently processing.
  bool get isProcessing => _isProcessing;

  /// Get the number of pending operations.
  int get pendingCount => _queue.length;

  /// Clear all pending operations.
  void clear() {
    _queue.clear();
    _notifyListeners();
  }
}

class _Operation {
  final Future Function() operation;
  final String? label;

  _Operation({required this.operation, this.label});
}
