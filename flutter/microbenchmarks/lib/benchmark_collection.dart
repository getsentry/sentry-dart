// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:flutter_test/flutter_test.dart';

import 'benchmark_binding.dart';
import 'ui/image_bench.dart' as image_bench;

// typedef Benchmark = (String name, Future<void> Function() value);
class Benchmark {
  const Benchmark(this.$1, this.$2);

  final String $1;
  final Future<void> Function() $2;
}

Future<void> main() async {
  // BenchmarkingBinding is used by animation_bench, providing a simple
  // stopwatch interface over rendering. Lifting it here makes all
  // benchmarks run together.
  final BenchmarkingBinding binding = BenchmarkingBinding();
  final List<Benchmark> benchmarks = <Benchmark>[
    Benchmark('ui/image_bench.dart', image_bench.execute),
  ];

  // Parses the optional compile-time dart variables; we can't have
  // arguments passed in to main.
  final ArgParser parser = ArgParser();
  final List<String> allowed = benchmarks.map((Benchmark e) => e.$1).toList();
  parser.addMultiOption(
    'tests',
    abbr: 't',
    defaultsTo: allowed,
    allowed: allowed,
    help: 'selected tests to run',
  );
  parser.addOption('seed',
      defaultsTo: '12345', help: 'selects seed to sort tests by');
  final List<String> mainArgs = <String>[];
  const String testArgs = String.fromEnvironment('tests');
  if (testArgs.isNotEmpty) {
    mainArgs.addAll(<String>['--tests', testArgs]);
    print('╡ ••• environment test override: $testArgs ••• ╞');
  }
  const String seedArgs = String.fromEnvironment('seed');
  if (seedArgs.isNotEmpty) {
    mainArgs.addAll(<String>['--seed', seedArgs]);
    print('╡ ••• environment seed override: $seedArgs ••• ╞');
  }
  final ArgResults results = parser.parse(mainArgs);
  final List<String> selectedTests = results.multiOption('tests');

  // Shuffle the tests because we don't want order dependent tests.
  // It is the responsibility of the infra to tell us what the seed value is,
  // in case we want to have the seed stable for some time period.
  final List<Benchmark> tests =
      benchmarks.where((Benchmark e) => selectedTests.contains(e.$1)).toList();
  tests.shuffle(Random(int.parse(results.option('seed')!)));

  // Wait for the app to stabilize before running the benchmarks.
  await Future<void>.delayed(const Duration(seconds: 1));

  print('╡ ••• Running microbenchmarks ••• ╞');
  for (final Benchmark mark in tests) {
    // Reset the frame policy to default - each test can set it on their own.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;
    print('╡ ••• Running ${mark.$1} ••• ╞');
    await mark.$2();
  }

  print('\n\n╡ ••• Done ••• ╞\n\n');
  exit(0);
}
