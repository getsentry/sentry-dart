import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  late final _lib = cocoa.SentryCocoa(DynamicLibrary.process());

  SentryNativeCocoa(super.channel);

  @override
  int? startProfiler(SentryId traceId) {
    final cSentryId = cocoa.SentryId1.alloc(_lib)
      ..initWithUUIDString_(cocoa.NSString(_lib, traceId.toString()));
    final startTime =
        cocoa.PrivateSentrySDKOnly.startProfilerForTrace_(_lib, cSentryId);
    return startTime;
  }
}
