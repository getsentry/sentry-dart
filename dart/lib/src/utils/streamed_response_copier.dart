import 'dart:async';
import 'package:http/http.dart';

class StreamedResponseCopier {
  final StreamController<List<int>> _streamController;
  final List<List<int>> _cache = [];
  bool _isDone = false;
  final StreamedResponse originalResponse;

  StreamedResponseCopier(this.originalResponse)
      : _streamController = StreamController<List<int>>.broadcast() {
    // Listen to the original stream and cache the data
    originalResponse.stream.listen(
      (data) {
        _cache.add(data); // Cache the data
        _streamController.add(data); // Forward the data
      },
      onError: _streamController.addError,
      onDone: () {
        _isDone = true;
        _streamController.close();
      },
    );
  }

  /// Get a copied StreamedResponse
  StreamedResponse copy() {
    if (_streamController.isClosed) {
      throw StateError(
          'Cannot create a new stream after the copier is disposed');
    }
    final Stream<List<int>> replayStream = _getReplayStream();
    return StreamedResponse(
      replayStream,
      originalResponse.statusCode,
      contentLength: originalResponse.contentLength,
      request: originalResponse.request,
      headers: originalResponse.headers,
      isRedirect: originalResponse.isRedirect,
      reasonPhrase: originalResponse.reasonPhrase,
    );
  }

  /// Create a stream that replays the cached data and listens to future updates
  Stream<List<int>> _getReplayStream() async* {
    // Create a snapshot of the current cache to iterate over
    final cacheSnapshot = List<List<int>>.from(_cache);

    // Replay cached data
    for (final chunk in cacheSnapshot) {
      yield chunk;
    }

    // Stream new data if the original stream is not done
    if (!_isDone) {
      yield* _streamController.stream;
    }
  }

  /// Dispose resources when done
  Future dispose() async {
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }
}
