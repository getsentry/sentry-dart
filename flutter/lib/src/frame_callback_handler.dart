import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract class IFrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback, {String debugLabel});
}

class DefaultFrameCallbackHandler implements IFrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback,
      {String debugLabel = 'callback'}) {
    WidgetsBinding.instance.addPostFrameCallback(callback);
  }
}
