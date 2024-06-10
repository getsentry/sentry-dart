import 'package:meta/meta.dart';

// A wrapper function around StackTrace.current so we can ignore it in the SDK
// crash detection. Otherwise, the SDK crash detection would have to ignore the
// method calling StackTrace.current, and it can't detect crashes in that
// method.
// You can read about the SDK crash detection here:
// https://github.com/getsentry/sentry/blob/master/src/sentry/utils/sdk_crashes/README.rst
@internal
StackTrace getCurrentStackTrace() => StackTrace.current;
