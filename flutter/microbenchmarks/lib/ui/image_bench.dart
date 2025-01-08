// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common.dart';

const List<String> assets = <String>[];

// Measures the time it takes to load a fixed number of assets into an
// immutable buffer to later be decoded by skia.
Future<void> execute() async {
  assert(false,
      "Don't run benchmarks in debug mode! Use 'flutter run --release'.");

  final Stopwatch watch = Stopwatch();
  await benchmarkWidgets((WidgetTester tester) async {
    watch.start();
    for (int i = 0; i < 10; i += 1) {
      await Future.wait(<Future<ui.ImmutableBuffer>>[
        for (final String asset in assets) rootBundle.loadBuffer(asset),
      ]);
    }
    watch.stop();
  });

  final BenchmarkResultPrinter printer = BenchmarkResultPrinter();
  printer.addResult(
    description: 'Image loading',
    value: watch.elapsedMilliseconds.toDouble(),
    unit: 'ms',
    name: 'image_load_ms',
  );
  printer.printToStdout();
}
