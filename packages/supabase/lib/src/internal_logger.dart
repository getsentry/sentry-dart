import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
const internalLogger = SentryInternalLogger('sentry_supabase');
