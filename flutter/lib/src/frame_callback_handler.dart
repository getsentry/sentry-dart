import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract class FrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback);
}

class DefaultFrameCallbackHandler implements FrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback(callback);
  }
}
