@TestOn('vm')
library;

// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_info.dart';
import 'package:sentry_flutter/src/app_start/static_app_start_span_writer.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$StaticAppStartSpanWriter', () {
    test('writes attached app-start shape under ui.load root', () async {
      final transaction = fixture.startTransaction('root /');

      await fixture.sut.writeAttached(transaction, fixture.appStartInfo);

      final appStartSpan = transaction.findSpan('Cold Start')!;
      expect(transaction.measurements['app_start_cold']?.value, 50);
      expect(transaction.data['app_start_type'], 'cold');
      expect(appStartSpan.context.operation, 'app.start.cold');
      expect(appStartSpan.origin, isNull);
      expect(appStartSpan.context.parentSpanId, transaction.context.spanId);
      expect(
        transaction
            .findSpan(AppStartInfo.pluginRegistrationDescription)
            ?.context
            .parentSpanId,
        appStartSpan.context.spanId,
      );
      expect(transaction.findSpan('native span')?.data['native'], isTrue);
    });

    test('writes standalone breakdown spans directly under root', () async {
      final transaction = fixture.startTransaction('App Start');

      await fixture.sut.writeStandalone(transaction, fixture.appStartInfo);
      fixture.sut.writeStandaloneEncoding(transaction, fixture.appStartInfo);

      expect(transaction.findSpan('Cold Start'), isNull);
      expect(transaction.measurements['app_start_cold']?.value, 50);
      expect(transaction.data['app.vitals.start.value'], 50.0);
      expect(transaction.data['app.vitals.start.type'], 'cold');
      for (final span in transaction.children) {
        expect(span.context.parentSpanId, transaction.context.spanId);
        expect(span.origin, SentryTraceOrigins.autoAppStart);
      }
      expect(
        transaction
            .findSpan(AppStartInfo.pluginRegistrationDescription)
            ?.context
            .operation,
        SentrySpanOperations.appStartPluginRegistration,
      );
      expect(
        transaction.findSpan('native span')?.context.operation,
        SentrySpanOperations.appStartNative,
      );
    });
  });
}

class Fixture {
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
  late final hub = Hub(options);
  late final sut = StaticAppStartSpanWriter(hub: hub);

  final appStartInfo = AppStartInfo(
    AppStartType.cold,
    start: DateTime.fromMillisecondsSinceEpoch(0),
    end: DateTime.fromMillisecondsSinceEpoch(50),
    pluginRegistration: DateTime.fromMillisecondsSinceEpoch(10),
    sentrySetupStart: DateTime.fromMillisecondsSinceEpoch(15),
    nativeSpanTimes: [
      TimeSpan(
        start: DateTime.fromMillisecondsSinceEpoch(1),
        end: DateTime.fromMillisecondsSinceEpoch(2),
        description: 'native span',
      ),
    ],
  );

  SentryTracer startTransaction(String name) {
    return hub.startTransaction(
      name,
      SentrySpanOperations.uiLoad,
      startTimestamp: appStartInfo.start,
    ) as SentryTracer;
  }
}

extension on SentryTracer {
  SentrySpan? findSpan(String description) {
    return children.firstWhereOrNull(
      (span) => span.context.description == description,
    );
  }
}
