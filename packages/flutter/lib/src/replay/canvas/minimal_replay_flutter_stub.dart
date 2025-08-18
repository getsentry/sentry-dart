import 'minimal_replay.dart' show ReplayRecorderController;

typedef OnPaintFrame = Future<void> Function(
    ReplayRecorderController controller);

OnPaintFrame flutterRenderViewOnPaintFrame() {
  return (ReplayRecorderController controller) async {};
}
