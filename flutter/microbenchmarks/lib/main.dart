import 'dart:io';
import 'src/image_bench.dart' as image_bench;
import 'src/memory_bench.dart' as memory_bench;
import 'src/jni_bench.dart' as jni_bench;

typedef BenchmarkSet = (String name, Future<void> Function() callback);

const filter = String.fromEnvironment("FILTER");

Future<void> main() async {
  final benchmarks = <BenchmarkSet>[
    ('Image', image_bench.execute),
    ('Memory', memory_bench.execute),
    if (Platform.isAndroid) ('JNI', jni_bench.execute),
  ];

  RegExp? filterRegexp;
  if (filter.isNotEmpty) {
    print('Filtering benchmarks with "$filter"');
    filterRegexp = RegExp(filter, caseSensitive: false);
  }

  for (final benchmark in benchmarks) {
    if (filterRegexp != null && !filterRegexp.hasMatch(benchmark.$1)) {
      print('BenchmarkSet ${benchmark.$1}: skipped due to filter');
      continue;
    }

    final watch = Stopwatch()..start();
    print('BenchmarkSet ${benchmark.$1}: starting');
    await benchmark.$2.call();
    print('BenchmarkSet ${benchmark.$1}: finished in ${watch.elapsed}');
    print('');
  }
  print('All benchmarks finished');
  exit(0);
}
