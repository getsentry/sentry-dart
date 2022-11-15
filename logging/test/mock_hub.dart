import 'package:meta/meta.dart';

import 'package:sentry/sentry.dart';

import 'no_such_method_provider.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

class MockHub with NoSuchMethodProvider implements Hub {
  final List<Breadcrumb> breadcrumbs = [];
  final List<CapturedEvents> events = [];
  final _options = SentryOptions(dsn: 'fixture-dsn');

  @override
  @internal
  SentryOptions get options => _options;

  @override
  Future<void> addBreadcrumb(Breadcrumb crumb, {Hint? hint}) async {
    breadcrumbs.add(crumb);
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Hint? hint,
    ScopeCallback? withScope,
  }) async {
    events.add(CapturedEvents(event, stackTrace));
    return SentryId.newId();
  }
}

class CapturedEvents {
  CapturedEvents(this.event, this.stackTrace);

  final SentryEvent event;
  final dynamic stackTrace;
}
