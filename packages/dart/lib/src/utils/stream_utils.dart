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
  List<int>? overflow;

  while (builder.length < maxBytes && await iterator.moveNext()) {
    final chunk = iterator.current;
    final remaining = maxBytes - builder.length;
    if (chunk.length > remaining) {
      // A single chunk can outsize the whole cap (e.g. a stream that hands
      // back its entire body as one chunk); only buffer up to the cap and
      // keep the rest to replay, rather than growing the buffer past it.
      builder.add(chunk.sublist(0, remaining));
      overflow = chunk.sublist(remaining);
      break;
    }
    builder.add(chunk);
  }

  final buffered = builder.takeBytes();

  Stream<List<int>> replay() async* {
    if (buffered.isNotEmpty) {
      yield buffered;
    }
    if (overflow != null) {
      yield overflow;
    }
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  return (buffered, replay());
}
