@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_event_processor.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_integration.dart';

import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('viewHierarchyIntegration creates view hierarchy processor', () {
    final integration = fixture.getSut();

    integration(fixture.hub, fixture.options);

    final processors = fixture.options.eventProcessors
        .where((e) => e.runtimeType == SentryViewHierarchyEventProcessor);

    expect(processors.isNotEmpty, true);
  });

  test(
      'viewHierarchyIntegration does not add view hierarchy processor if opt out in options',
      () {
    final integration = fixture.getSut(attachViewHierarchy: false);

    integration(fixture.hub, fixture.options);

    final processors = fixture.options.eventProcessors
        .where((e) => e.runtimeType == SentryViewHierarchyEventProcessor);

    expect(processors.isEmpty, true);
  });

  test('viewHierarchyIntegration close resets processor', () {
    final integration = fixture.getSut();

    integration(fixture.hub, fixture.options);
    integration.close();

    final processors = fixture.options.eventProcessors
        .where((e) => e.runtimeType == SentryViewHierarchyEventProcessor);

    expect(processors.isEmpty, true);
  });

  test('viewHierarchyIntegration adds integration to the sdk list', () {
    final integration = fixture.getSut();

    integration(fixture.hub, fixture.options);

    expect(
        fixture.options.sdk.integrations.contains('viewHierarchyIntegration'),
        true);
  });

  test('viewHierarchyIntegration does not add integration to the sdk list', () {
    final integration = fixture.getSut(attachViewHierarchy: false);

    integration(fixture.hub, fixture.options);

    expect(
        fixture.options.sdk.integrations.contains('viewHierarchyIntegration'),
        false);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions();

  SentryViewHierarchyIntegration getSut({bool attachViewHierarchy = true}) {
    options.attachViewHierarchy = attachViewHierarchy;
    return SentryViewHierarchyIntegration();
  }
}
