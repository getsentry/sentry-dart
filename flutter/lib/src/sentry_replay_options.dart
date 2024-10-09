import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'replay/masking_config.dart';
import 'replay/widget_filter.dart';
import 'screenshot/sentry_mask_widget.dart';
import 'screenshot/sentry_unmask_widget.dart';

/// Configuration of the experimental replay feature.
@experimental
class SentryReplayOptions {
  double? _sessionSampleRate;

  /// A percentage of sessions in which a replay will be created.
  /// The value needs to be >= 0.0 and <= 1.0.
  /// Specifying 0 means none, 1.0 means 100 %. Defaults to null (disabled).
  double? get sessionSampleRate => _sessionSampleRate;
  set sessionSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _sessionSampleRate = value;
  }

  double? _onErrorSampleRate;

  /// A percentage of errors that will be accompanied by a 30 seconds replay.
  /// The value needs to be >= 0.0 and <= 1.0.
  /// Specifying 0 means none, 1.0 means 100 %. Defaults to null (disabled).
  double? get onErrorSampleRate => _onErrorSampleRate;
  set onErrorSampleRate(double? value) {
    assert(value == null || (value >= 0 && value <= 1));
    _onErrorSampleRate = value;
  }

  /// Mask all text content. Draws a rectangle of text bounds with text color
  /// on top. Currently, only [Text] and [EditableText] Widgets are redacted.
  /// Default is enabled.
  var maskAllText = true;

  @Deprecated('Use maskAllText instead')
  bool get redactAllText => maskAllText;
  set redactAllText(bool value) => maskAllText = value;

  /// Mask content of all images. Draws a rectangle of image bounds with image's
  /// dominant color on top. Currently, only [Image] widgets are redacted.
  /// Default is enabled (except for asset images, see [maskAssetImages]).
  var maskAllImages = true;

  @Deprecated('Use maskAllImages instead')
  bool get redactAllImages => maskAllImages;
  set redactAllImages(bool value) => maskAllImages = value;

  /// Redact asset images coming from the root asset bundle.
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
  void maskCallback<T extends Widget>(
      SentryMaskingDecision Function(Element, T) shouldMask) {
    assert(T != SentryMask);
    assert(T != SentryUnmask);
    _userMaskingRules.add(SentryMaskingCustomRule<T>(shouldMask));
  }

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((onErrorSampleRate ?? 0) > 0);
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
