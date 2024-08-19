/// A Flutter client for Sentry.io crash reporting.
library sentry_flutter;

// ignore: invalid_export_of_internal_element
export 'package:sentry/sentry.dart';

export 'src/integrations/load_release_integration.dart';
export 'src/navigation/sentry_navigator_observer.dart';
export 'src/sentry_flutter.dart';
export 'src/sentry_flutter_options.dart';
export 'src/flutter_sentry_attachment.dart';
export 'src/sentry_asset_bundle.dart';
export 'src/integrations/on_error_integration.dart';
export 'src/screenshot/sentry_screenshot_widget.dart';
export 'src/screenshot/sentry_screenshot_quality.dart';
export 'src/user_interaction/sentry_user_interaction_widget.dart';
export 'src/binding_wrapper.dart';
export 'src/sentry_widget.dart';
export 'src/navigation/sentry_display_widget.dart';
