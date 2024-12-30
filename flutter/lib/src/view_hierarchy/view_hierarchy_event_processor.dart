import 'dart:async';

import '../../sentry_flutter.dart';
import '../utils/debouncer.dart';
import 'sentry_tree_walker.dart';

/// A [EventProcessor] that renders an ASCII representation of the entire view
/// hierarchy of the application when an error happens and includes it as an
/// attachment to the [Hint].
class SentryViewHierarchyEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;
  late final Debouncer _debouncer;

  SentryViewHierarchyEventProcessor(this._options) {
    _debouncer = Debouncer(
      // ignore: invalid_use_of_internal_member
      _options.clock,
      waitTime: Duration(milliseconds: 2000),
    );
  }

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event is SentryTransaction) {
      return event;
    }

    if (event.exceptions == null && event.throwable == null) {
      return event;
    }

    final instance = _options.bindingUtils.instance;
    if (instance == null) {
      return event;
    }

    // skip capturing in case of debouncing (=too many frequent capture requests)
    // the BeforeCaptureCallback may overrule the debouncing decision
    final shouldDebounce = _debouncer.shouldDebounce();

    try {
      final beforeCapture = _options.beforeCaptureViewHierarchy;
      FutureOr<bool>? result;

      if (beforeCapture != null) {
        result = beforeCapture(event, hint, shouldDebounce);
      }

      bool captureViewHierarchy = true;

      if (result != null) {
        if (result is Future<bool>) {
          captureViewHierarchy = await result;
        } else {
          captureViewHierarchy = result;
        }
      } else if (shouldDebounce) {
        _options.logger(
          SentryLevel.debug,
          'Skipping view hierarchy capture due to debouncing (too many captures within ${_debouncer.waitTime.inMilliseconds}ms)',
        );
        captureViewHierarchy = false;
      }

      if (!captureViewHierarchy) {
        return event;
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'The beforeCaptureViewHierarchy callback threw an exception',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }

    final sentryViewHierarchy = walkWidgetTree(instance, _options);
    if (sentryViewHierarchy == null) {
      return event;
    }
    hint.viewHierarchy =
        SentryAttachment.fromViewHierarchy(sentryViewHierarchy);
    return event;
  }
}
