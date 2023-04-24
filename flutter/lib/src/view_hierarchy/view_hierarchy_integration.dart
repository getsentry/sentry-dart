import '../../sentry_flutter.dart';
import 'view_hierarchy_event_processor.dart';

/// A [Integration] that renders an ASCII represention of the entire view
/// hierarchy of the application when an error happens and includes it as an
/// attachment to the [Hint].
class SentryViewHierarchyIntegration
    implements Integration<SentryFlutterOptions> {
  SentryViewHierarchyEventProcessor? _eventProcessor;
  SentryFlutterOptions? _options;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    // View hierarchy is always minified on Web and we don't support
    // symbolication of source maps for view hierarchy yet.
    if (!options.attachViewHierarchy || options.platformChecker.isWeb) {
      return;
    }
    _options = options;
    final eventProcessor = SentryViewHierarchyEventProcessor(options);
    options.addEventProcessor(eventProcessor);
    _eventProcessor = eventProcessor;
    options.sdk.addIntegration('viewHierarchyIntegration');
  }

  @override
  void close() {
    final eventProcessor = _eventProcessor;
    if (eventProcessor != null) {
      _options?.removeEventProcessor(eventProcessor);
      _eventProcessor = null;
    }
  }
}
