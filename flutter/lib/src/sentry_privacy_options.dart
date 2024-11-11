import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'screenshot/masking_config.dart';
import 'screenshot/widget_filter.dart';

/// Configuration of the experimental privacy feature.
class SentryPrivacyOptions {
  /// Mask all text content. Draws a rectangle of text bounds with text color
  /// on top. Currently, only [Text] and [EditableText] Widgets are masked.
  /// Default is enabled.
  @experimental
  var maskAllText = true;

  /// Mask content of all images. Draws a rectangle of image bounds with image's
  /// dominant color on top. Currently, only [Image] widgets are redacted.
  /// Default is enabled (except for asset images, see [maskAssetImages]).
  @experimental
  var maskAllImages = true;

  /// Redact asset images coming from the root asset bundle.
  @experimental
  var maskAssetImages = false;

  final _userMaskingRules = <SentryMaskingRule>[];

  @internal
  SentryMaskingConfig buildMaskingConfig() {
    // First, we collect rules defined by the user (so they're applied first).
    final rules = _userMaskingRules.toList();

    // Then, we apply rules for [SentryMask] and [SentryUnmask].
    rules.add(const SentryMaskingConstantRule<SentryMask>(
        SentryMaskingDecision.mask));
    rules.add(const SentryMaskingConstantRule<SentryUnmask>(
        SentryMaskingDecision.unmask));

    // Then, we apply apply rules based on the configuration.
    if (maskAllImages) {
      if (maskAssetImages) {
        rules.add(
            const SentryMaskingConstantRule<Image>(SentryMaskingDecision.mask));
      } else {
        rules
            .add(const SentryMaskingCustomRule<Image>(_maskImagesExceptAssets));
      }
    } else {
      assert(!maskAssetImages,
          "maskAssetImages can't be true if maskAllImages is false");
    }
    if (maskAllText) {
      rules.add(
          const SentryMaskingConstantRule<Text>(SentryMaskingDecision.mask));
      rules.add(const SentryMaskingConstantRule<EditableText>(
          SentryMaskingDecision.mask));
    }
    return SentryMaskingConfig(rules);
  }

  /// Mask given widget type [T] (or subclasses of [T]) in the replay.
  /// Note: masking rules are called in the order they're added so if a previous
  /// rule already makes a decision, this rule won't be called.
  @experimental
  void mask<T extends Widget>() {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules
        .add(SentryMaskingConstantRule<T>(SentryMaskingDecision.mask));
  }

  /// Unmask given widget type [T] (or subclasses of [T]) in the replay. This is
  /// useful to explicitly show certain widgets that would otherwise be masked
  /// by other rules, for example default [maskAllText] or [maskAllImages].
  /// The [SentryMaskingDecision.unmask] will apply to the widget and its children,
  /// so no other rules will be checked for the children.
  /// Note: masking rules are called in the order they're added so if a previous
  /// rule already makes a decision, this rule won't be called.
  @experimental
  void unmask<T extends Widget>() {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules
        .add(SentryMaskingConstantRule<T>(SentryMaskingDecision.unmask));
  }

  /// Provide a custom callback to decide whether to mask the widget of class
  /// [T] (or subclasses of [T]).
  /// Note: masking rules are called in the order they're added so if a previous
  /// rule already makes a decision, this rule won't be called.
  @experimental
  void maskCallback<T extends Widget>(
      SentryMaskingDecision Function(Element, T) shouldMask) {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules.add(SentryMaskingCustomRule<T>(shouldMask));
  }
}

SentryMaskingDecision _maskImagesExceptAssets(Element element, Widget widget) {
  if (widget is Image) {
    final image = widget.image;
    if (image is AssetBundleImageProvider) {
      if (WidgetFilter.isBuiltInAssetImage(image, rootBundle)) {
        return SentryMaskingDecision.continueProcessing;
      }
    }
  }
  return SentryMaskingDecision.mask;
}
