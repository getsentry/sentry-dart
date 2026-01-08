import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'screenshot/masking_config.dart';
import 'screenshot/widget_filter.dart';
// ignore: implementation_imports
import 'package:sentry/src/event_processor/enricher/flutter_runtime.dart'
    as flutter_runtime;

/// Configuration of the experimental privacy feature.
class SentryPrivacyOptions {
  /// Mask all text content. Draws a rectangle of text bounds with text color
  /// on top. Currently, only [Text] and [EditableText] Widgets are masked.
  /// Default is enabled.
  var maskAllText = true;

  /// Mask content of all images. Draws a rectangle of image bounds with image's
  /// dominant color on top. Currently, only [Image] widgets are masked.
  /// Default is enabled (except for asset images, see [maskAssetImages]).
  var maskAllImages = true;

  /// Redact asset images coming from the root asset bundle.
  var maskAssetImages = false;

  final _userMaskingRules = <SentryMaskingRule>[];

  @internal
  Iterable<SentryMaskingRule> get userMaskingRules => _userMaskingRules;

  @internal
  SentryMaskingConfig buildMaskingConfig(
      SdkLogCallback logger, RuntimeChecker runtimeChecker) {
    // First, we collect rules defined by the user (so they're applied first).
    final rules = _userMaskingRules.toList();

    // Then, we apply rules for [SentryMask] and [SentryUnmask].
    rules.add(const SentryMaskingConstantRule<SentryMask>(
      mask: true,
      name: 'SentryMask',
    ));
    rules.add(const SentryMaskingConstantRule<SentryUnmask>(
      mask: false,
      name: 'SentryUnmask',
    ));

    // Then, we apply apply rules based on the configuration.
    if (maskAllImages) {
      if (maskAssetImages) {
        rules.add(const SentryMaskingConstantRule<Image>(
          mask: true,
          name: 'Image',
        ));
      } else {
        rules.add(const SentryMaskingCustomRule<Image>(
            callback: _maskImagesExceptAssets,
            name: 'Image',
            description: 'Mask all images except asset images.'));
      }
    } else {
      assert(!maskAssetImages,
          "maskAssetImages can't be true if maskAllImages is false");
    }

    if (maskAllText) {
      rules.add(const SentryMaskingConstantRule<Text>(
        mask: true,
        name: 'Text',
      ));
      rules.add(const SentryMaskingConstantRule<EditableText>(
        mask: true,
        name: 'EditableText',
      ));
      rules.add(const SentryMaskingConstantRule<RichText>(
        mask: true,
        name: 'RichText',
      ));
    }

    const flutterVersion = flutter_runtime.FlutterVersion.version;
    if (flutterVersion != null) {
      _maybeAddSensitiveContentRule(rules, flutterVersion);
    }

    // In Debug mode, check if users explicitly mask (or unmask) widgets that
    // look like they should be masked, e.g. Videos, WebViews, etc.
    if (runtimeChecker.isDebugMode()) {
      final regexp = RegExp('video|webview|password|pinput|camera|chart',
          caseSensitive: false);

      rules.add(SentryMaskingCustomRule<Widget>(
          callback: (Element element, Widget widget) {
            if (widget is InheritedWidget) {
              return SentryMaskingDecision.continueProcessing;
            }
            final type = widget.runtimeType.toString();
            if (regexp.hasMatch(type)) {
              logger(
                  SentryLevel.warning,
                  'Widget "$widget" name matches widgets that should usually be '
                  'masked because they may contain sensitive data. Because this '
                  'widget comes from a third-party plugin or your code, Sentry '
                  "doesn't recognize it and can't reliably mask it in release "
                  'builds (due to obfuscation). '
                  'Please mask it explicitly using options.privacy.mask<$type>(). '
                  'If you want to silence this warning and keep the widget '
                  'visible in captures, you can use options.privacy.unmask<$type>(). '
                  'Note: the RegExp matched is: $regexp (case insensitive).');
            }
            return SentryMaskingDecision.continueProcessing;
          },
          name: 'Widget',
          description:
              'Debug-mode-only warning for potentially sensitive widgets.'));
    }

    return SentryMaskingConfig(rules);
  }

  /// Mask given widget type [T] (or subclasses of [T]) in the replay.
  /// Note: masking rules are called in the order they're added so if a previous
  /// rule already makes a decision, this rule won't be called.
  @experimental
  void mask<T extends Widget>({String? name, String? description}) {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules.add(SentryMaskingConstantRule<T>(
      mask: true,
      name: name ?? T.toString(),
      description: description,
    ));
  }

  /// Unmask given widget type [T] (or subclasses of [T]) in the replay. This is
  /// useful to explicitly show certain widgets that would otherwise be masked
  /// by other rules, for example default [maskAllText] or [maskAllImages].
  /// The [SentryMaskingDecision.unmask] will apply to the widget and its children,
  /// so no other rules will be checked for the children.
  /// Note: masking rules are called in the order they're added so if a previous
  /// rule already makes a decision, this rule won't be called.
  @experimental
  void unmask<T extends Widget>({String? name, String? description}) {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules.add(SentryMaskingConstantRule<T>(
      mask: false,
      name: name ?? T.toString(),
      description: description,
    ));
  }

  /// Provide a custom callback to decide whether to mask the widget of class
  /// [T] (or subclasses of [T]).
  /// Note: masking rules are called in the order they're added so if a previous
  /// rule already makes a decision, this rule won't be called.
  @experimental
  void maskCallback<T extends Widget>(
      SentryMaskingDecision Function(Element, T) shouldMask,
      {String? name,
      String? description}) {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules.add(SentryMaskingCustomRule<T>(
      callback: shouldMask,
      name: name ?? T.toString(),
      description:
          description ?? 'Custom callback-based rule (description unspecified)',
    ));
  }

  Map<String, dynamic> toJson() => {
        'maskAllText': maskAllText,
        'maskAllImages': maskAllImages,
        'maskAssetImages': maskAssetImages,
        if (userMaskingRules.isNotEmpty)
          'maskingRules': userMaskingRules
              .map((rule) => '${rule.name}: ${rule.description}')
              .toList(growable: false),
      };
}

/// Minimum Flutter version required for SensitiveContent widget support.
const _sensitiveContentMinMajor = 3;
const _sensitiveContentMinMinor = 33;

/// Determines if the SensitiveContent masking rule should be added
/// based on parsed version components.
///
/// Returns `false` if [components] is `null` (malformed version string).
@visibleForTesting
bool shouldAddSensitiveContentRule(
    flutter_runtime.FlutterVersionComponents? components) {
  return components?.meetsMinimum(
          _sensitiveContentMinMajor, _sensitiveContentMinMinor) ??
      false;
}

/// Detects if a widget is a SensitiveContent widget at runtime.
///
/// Uses dynamic property access to check for the `sensitivity` property,
/// which is unique to the SensitiveContent widget. This approach works in
/// obfuscated builds where type names are mangled.
///
/// Returns `true` if the widget has a `sensitivity` property that is an
/// [Enum] (as expected from SensitiveContent widget).
@visibleForTesting
bool isSensitiveContentWidget(Widget widget) {
  try {
    final dynamic dynWidget = widget;
    final sensitivity = dynWidget.sensitivity;
    // The property must exist AND be an Enum to be considered SensitiveContent.
    // This check is done at runtime (not via assert) to ensure consistent
    // behavior in both debug and release modes.
    if (sensitivity is! Enum) {
      return false;
    }
    return true;
  } catch (_) {
    // Property not found – not a SensitiveContent widget.
    return false;
  }
}

/// Adds a masking rule for the [SensitiveContent] widget.
///
/// The rule masks any widget that exposes a `sensitivity` property which is an
/// [Enum]. This is how the [SensitiveContent] widget can be detected
/// without depending on its type directly (which would fail to compile on
/// older Flutter versions).
void _maybeAddSensitiveContentRule(
    List<SentryMaskingRule> rules, String flutterVersion) {
  final components =
      flutter_runtime.FlutterVersion.parseComponents(flutterVersion);
  if (!shouldAddSensitiveContentRule(components)) {
    return;
  }

  SentryMaskingDecision maskSensitiveContent(Element element, Widget widget) {
    return isSensitiveContentWidget(widget)
        ? SentryMaskingDecision.mask
        : SentryMaskingDecision.continueProcessing;
  }

  rules.add(SentryMaskingCustomRule<Widget>(
    callback: maskSensitiveContent,
    name: 'SensitiveContent',
    description: 'Mask SensitiveContent widget.',
  ));
}

SentryMaskingDecision _maskImagesExceptAssets(Element element, Image widget) {
  final image = widget.image;
  if (image is AssetBundleImageProvider) {
    if (WidgetFilter.isBuiltInAssetImage(image, rootBundle)) {
      return SentryMaskingDecision.continueProcessing;
    }
  }
  return SentryMaskingDecision.mask;
}
