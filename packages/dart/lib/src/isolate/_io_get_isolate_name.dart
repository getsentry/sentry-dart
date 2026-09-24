import 'dart:isolate';

String? getIsolateName() => Isolate.current.debugName;
