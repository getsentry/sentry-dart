import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:test/test.dart';

void main() {
  test('$FlutterVersion.isPrerelease()', () async {
    expect(FlutterVersion('v1.16.3').isPreRelease, false);
    expect(FlutterVersion('v1.16.3.pre').isPreRelease, true);
    expect(FlutterVersion('3.16.0-9.0').isPreRelease, false);
    expect(FlutterVersion('3.16.0-9.0.pre').isPreRelease, true);
  });
}
