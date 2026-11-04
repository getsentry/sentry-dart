import 'package:meta/meta.dart';

/// Whether [event] (a dartified rrweb recording event) is the JS SDK's own
/// DOM click breadcrumb whose target is Flutter's root `<flutter-view>`.
///
/// The whole Flutter app is rendered into that one element, so this
/// breadcrumb ("body > flutter-view") says nothing about what was tapped.
/// The Dart SDK's `flutter.ui.click` breadcrumb carries the real widget, so
/// this one is dropped. Clicks on other elements (platform views, semantics
/// nodes) are kept.
@internal
bool isFlutterViewClickEvent(Map<dynamic, dynamic>? event) {
  // 5 = rrweb `EventType.Custom`.
  if (event == null || event['type'] != 5) return false;

  final data = event['data'];
  if (data is! Map || data['tag'] != 'breadcrumb') return false;

  final payload = data['payload'];
  if (payload is! Map || payload['category'] != 'ui.click') return false;

  final breadcrumbData = payload['data'];
  if (breadcrumbData is! Map) return false;

  final node = breadcrumbData['node'];
  return node is Map && node['tagName'] == 'flutter-view';
}
