import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Eagerly reads up to [maxBytes] from [stream], then returns those buffered
/// bytes together with a stream that replays them followed by the remainder
/// of [stream], read lazily as it's consumed.
///
/// Lets a caller inspect a bounded prefix of a stream (e.g. to capture a
/// truncated copy of a response body) while still forwarding the untouched,
/// full stream onward — without buffering the whole thing in memory, which
/// matters when the stream is large or its length isn't known upfront.
@internal
Future<(Uint8List prefix, Stream<List<int>> forwarded)> bufferStreamPrefix(
  Stream<List<int>> stream, {
  required int maxBytes,
}) async {
  final iterator = StreamIterator(stream);
  final builder = BytesBuilder(copy: false);

  while (builder.length < maxBytes && await iterator.moveNext()) {
    builder.add(iterator.current);
  }

  final buffered = builder.takeBytes();

  Stream<List<int>> replay() async* {
    if (buffered.isNotEmpty) {
      yield buffered;
    }
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  return (buffered, replay());
}
