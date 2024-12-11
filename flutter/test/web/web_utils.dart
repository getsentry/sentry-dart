// ignore: depend_on_referenced_packages
import 'package:web/web.dart';

void injectMetaTag(Map<String, String> attributes) {
  final HTMLMetaElement meta =
      document.createElement('meta') as HTMLMetaElement;
  for (final MapEntry<String, String> attribute in attributes.entries) {
    meta.setAttribute(attribute.key, attribute.value);
  }
  document.head!.appendChild(meta);
}
