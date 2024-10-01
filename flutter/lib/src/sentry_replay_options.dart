import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'replay/masking_config.dart';
import 'replay/widget_filter.dart';

/// Configuration of the experimental replay feature.
class SentryReplayOptions {
  SentryReplayOptions() {
    redactAllText = true;
    redactAllImages = true;
  }

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
  bool maskAllText = true;

  @Deprecated('Use maskAllText instead')
  bool get redactAllText => maskAllText;
  set redactAllText(bool value) => maskAllText = value;

  /// Mask content of all images. Draws a rectangle of image bounds with image's
  /// dominant color on top. Currently, only [Image] widgets are redacted.
  /// Default is enabled (except for asset images, see [maskAssetImages]).
  bool maskAllImages = true;

  @Deprecated('Use maskAllImages instead')
  bool get redactAllImages => maskAllImages;
  set redactAllImages(bool value) => maskAllImages = value;

  /// Redact asset images coming from the root asset bundle.
  bool maskAssetImages = false;

  final _userMaskingRules = <SentryMaskingRule>[];

  @internal
  SentryMaskingConfig buildMaskingConfig() {
    final rules = _userMaskingRules.toList();
    if (maskAllImages) {
      if (maskAssetImages) {
        rules.add(const SentryMaskingConstantRule<Image>(MaskingDecision.mask));
      } else {
        rules
            .add(const SentryMaskingCustomRule<Image>(_maskImagesExceptAssets));
      }
    } else {
      assert(!maskAssetImages,
          "maskAssetImages can't be true if maskAllImages is false");
    }
    if (maskAllText) {
      rules.add(const SentryMaskingConstantRule<Text>(MaskingDecision.mask));
      rules.add(
          const SentryMaskingConstantRule<EditableText>(MaskingDecision.mask));
    }
    return SentryMaskingConfig(rules);
  }

  /// Mask given widget type (or it's subclasses) in the replay.
  /// Note: masking rules are called in the order they're added.
  void mask<T extends Widget>() {
    _userMaskingRules.add(SentryMaskingConstantRule<T>(MaskingDecision.mask));
  }

  /// Unmask given widget type (or it's subclasses) in the replay, if it would
  /// have otherwise been masked by other rules, for example the default rules
  /// [maskAllText] or [maskAllImages].
  void unmask<T extends Widget>() {
    _userMaskingRules.add(SentryMaskingConstantRule<T>(MaskingDecision.unmask));
  }

  /// Provide a custom callback to decide whether to mask the widget.
  /// Note: masking rules are called in the order they're added.
  void maskCallback<T extends Widget>(
      MaskingDecision Function(Element, T) shouldMask) {
    _userMaskingRules.add(SentryMaskingCustomRule<T>(shouldMask));
  }

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((onErrorSampleRate ?? 0) > 0);
}

MaskingDecision _maskImagesExceptAssets(Element element, Widget widget) {
  if (widget is Image) {
    final image = widget.image;
    if (image is AssetBundleImageProvider) {
      if (WidgetFilter.isBuiltInAssetImage(image, rootBundle)) {
        return MaskingDecision.continueProcessing;
      }
    }
  }
  return MaskingDecision.mask;
}
