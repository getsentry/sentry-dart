import 'dart:convert';

import 'package:crypto/crypto.dart';

/// final rand = XorShiftRandom('wohoo');
/// rand.next();
class XorShiftRandom {
  List<int> state = [0, 0, 0, 0];
  static const mask = 0xffffffff;

  XorShiftRandom(String seed) {
    _seed(seed);
  }

  void _seed(String seed) {
    final encoded = utf8.encode(seed);
    final bytes = sha1.convert(encoded).bytes;
    final slice = bytes.sublist(0, 16);

    for (var i = 0; i < state.length; i++) {
      final unpack = (slice[i * 4] << 24) |
          (slice[i * 4 + 1] << 16) |
          (slice[i * 4 + 2] << 8) |
          (slice[i * 4 + 3]);
      state[i] = unpack;
    }
  }

  double next() {
    return nextu32() / mask;
  }

  int nextu32() {
    var t = state[3];
    final s = state[0];

    state[3] = state[2];
    state[2] = state[1];
    state[1] = s;

    t = (t << 11) & mask;
    t ^= t >> 8;
    state[0] = (t ^ s ^ (s >> 19)) & mask;

    return state[0];
  }
}
