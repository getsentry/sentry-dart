import 'dart:collection';

import '../../sentry.dart';

abstract interface class MutableAttributes {
  Map<String, SentryAttribute> get attributes;
  void setAttribute(String key, SentryAttribute value);
  void setAttributes(Map<String, SentryAttribute> attributes);
  void removeAttribute(String key);
}

abstract mixin class MutableAttributesMixin implements MutableAttributes {
  final Map<String, SentryAttribute> _attributes = {};

  @override
  Map<String, SentryAttribute> get attributes =>
      UnmodifiableMapView(_attributes);

  @override
  void setAttribute(String key, SentryAttribute value) =>
      _attributes[key] = value;

  @override
  void setAttributes(Map<String, SentryAttribute> attrs) =>
      _attributes.addAll(attrs);

  @override
  void removeAttribute(String key) => _attributes.remove(key);
}
