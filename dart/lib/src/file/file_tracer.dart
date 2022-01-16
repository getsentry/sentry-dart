import '_io_file_tracer.dart' if (dart.library.html) '_no_op_file_tracer.dart'
    as file_tracer;

import 'dart:async';

import '../hub.dart';
import '../sentry.dart';
import '../sentry_options.dart';

FutureOr<void> runWithFileOverrides(
  AppRunner runner,
  Hub hub,
  SentryOptions options,
) =>
    file_tracer.runWithFileOverrides(runner, hub, options);
