// import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;
import 'package:objective_c/objective_c.dart' as objc;

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  // late final _lib = cocoa.SentryCocoa(DynamicLibrary.process()); // No more dylib loading?

  SentryNativeCocoa(super.channel);

  @override
  int? startProfiler(SentryId traceId) {
    final cSentryId = cocoa.SentryId1.alloc()
      ..initWithUUIDString_(objc.NSString(traceId.toString()));
    final startTime =
        cocoa.PrivateSentrySDKOnly.startProfilerForTrace_(cSentryId);
    return startTime;
  }
}
