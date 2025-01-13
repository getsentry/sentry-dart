import 'dart:io';
import 'src/image_bench.dart' as image_bench;
import 'src/memory_bench.dart' as memory_bench;

typedef BenchmarkSet = (String name, Future<void> Function() callback);

Future<void> main() async {
  final benchmarks = <BenchmarkSet>[
    ('Image', image_bench.execute),
    ('Memory', memory_bench.execute),
  ];

  for (final benchmark in benchmarks) {
    final watch = Stopwatch()..start();
    print('BenchmarkSet ${benchmark.$1}: starting');
    await benchmark.$2.call();
    print('BenchmarkSet ${benchmark.$1}: finished in ${watch.elapsed}');
    print('');
  }
  print('All benchmarks finished');
  exit(0);
}
