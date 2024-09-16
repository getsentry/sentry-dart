import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/integrations/on_error_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'mock_platform_dispatcher.dart';

void main() {
  // Not calling: TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  void _reportError({
    required Object exception,
    required StackTrace stackTrace,
    ErrorCallback? handler,
  }) {
    fixture.platformDispatcherWrapper.onError = handler ??
        (_, __) {
          return fixture.onErrorReturnValue;
        };

    when(fixture.hub.captureEvent(captureAny,
            stackTrace: captureAnyNamed('stackTrace')))
        .thenAnswer((_) => Future.value(SentryId.empty()));

    OnErrorIntegration(dispatchWrapper: fixture.platformDispatcherWrapper)(
      fixture.hub,
      fixture.options,
    );

    fixture.platformDispatcherWrapper.onError?.call(exception, stackTrace);
  }

  test('onError does not capture errors when binding is null', () async {
    final exception = StateError('error');

    _reportError(exception: exception, stackTrace: StackTrace.current);

    verifyNever(await fixture.hub
        .captureEvent(captureAny, stackTrace: captureAnyNamed('stackTrace')));
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
  late final platformDispatcherWrapper =
      PlatformDispatcherWrapper(MockPlatformDispatcher());

  bool onErrorReturnValue = true;
}
