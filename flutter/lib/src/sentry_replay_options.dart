import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

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

  /// Redact all text content. Draws a rectangle of text bounds with text color
  /// on top. Currently, only [Text] and [EditableText] Widgets are redacted.
  /// Default is enabled.
  set redactAllText(bool value) {
    if (value) {
      mask(Text);
      mask(EditableText);
    } else {
      unmask(Text);
      unmask(EditableText);
    }
  }

  /// Redact all image content. Draws a rectangle of image bounds with image's
  /// dominant color on top. Currently, only [Image] widgets are redacted.
  /// Default is enabled (except for asset images, see [maskAssetImages]).
  bool _maskImages = true;
  set redactAllImages(bool value) {
    _maskImages = value;
    if (value) {
      if (_maskAssetImages) {
        mask(Image);
      } else {
        maskIfTrue(Image, _maskImagesExceptAssets);
      }
    } else {
      unmask(Image);
    }
  }

  /// Redact asset iamges.
  bool _maskAssetImages = false;
  set maskAssetImages(bool value) {
    if (_maskAssetImages == value) {
      return;
    }
    _maskAssetImages = value;
    if (value) {
      assert(_maskImages);
      mask(Image);
    } else if (_maskImages) {
      maskIfTrue(Image, _maskImagesExceptAssets);
    } else {
      unmask(Image);
    }
  }

  Map<Type, WidgetFilterMaskingConfig> _maskingConfig = {};
  bool _finished = false;

  /// Once accessed, masking confing cannot change anymore.
  @internal
  Map<Type, WidgetFilterMaskingConfig> get maskingConfig {
    if (_finished) {
      return _maskingConfig;
    }
    _finished = true;
    final result =
        Map<Type, WidgetFilterMaskingConfig>.unmodifiable(_maskingConfig);
    _maskingConfig = result;
    return result;
  }

  /// Mask given widget type in the replay.
  void mask(Type type) {
    _maskingConfig[type] = WidgetFilterMaskingConfig.mask;
  }

  /// Unmask given widget type in the replay.
  void unmask(Type type) {
    _maskingConfig.remove(type);
  }

  /// Unmask given widget type in the replay if it's masked by default rules
  /// [redactAllText] or [redactAllImages].
  void maskIfTrue(Type type, bool Function(Element, Widget) shouldMask) {
    _maskingConfig[type] = WidgetFilterMaskingConfig.custom(shouldMask);
  }

  @internal
  bool get isEnabled =>
      ((sessionSampleRate ?? 0) > 0) || ((onErrorSampleRate ?? 0) > 0);
}

bool _maskImagesExceptAssets(Element element, Widget widget) {
  if (widget is Image) {
    final image = widget.image;
    if (image is AssetBundleImageProvider) {
      if (WidgetFilter.isBuiltInAssetImage(image, rootBundle)) {
        return false;
      }
    }
  }
  return true;
}
