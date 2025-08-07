import 'package:meta/meta.dart';

import 'package:sentry/sentry.dart';

import 'no_such_method_provider.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

SentryOptions defaultTestOptions() {
  // ignore: invalid_use_of_internal_member
  return SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
}

class MockHub with NoSuchMethodProvider implements Hub {
  final List<CapturedBreadcrumb> breadcrumbs = [];
  final List<CapturedEvents> events = [];
  final _options = defaultTestOptions();

  @override
  @internal
  SentryOptions get options => _options;

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    breadcrumbs.add(CapturedBreadcrumb(crumb, hint));
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) async {
    events.add(CapturedEvents(event, stackTrace, hint));
    return SentryId.newId();
  }
}

class CapturedEvents {
  CapturedEvents(this.event, this.stackTrace, this.hint);

  final SentryEvent event;
  final dynamic stackTrace;
  final Hint? hint;
}

class CapturedBreadcrumb {
  CapturedBreadcrumb(this.breadcrumb, this.hint);

  final Breadcrumb breadcrumb;
  final Hint? hint;
}
