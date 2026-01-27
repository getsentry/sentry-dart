import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart';

/// Logger for the Sentry Drift integration.
@internal
const internalLogger = SentryInternalLogger(loggerName);
