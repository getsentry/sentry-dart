// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../swipe_page_transitions_builder.dart';

/// A moving, maskable scene for eyeballing Session Replay masking (moving,
/// scaling and rotating content, and page transitions) in the Sentry
/// dashboard.
class ReplayPlaygroundScreen extends StatefulWidget {
  const ReplayPlaygroundScreen({
    super.key,
    this.initialScrollOffset = 0,
    this.depth = 1,
    this.maskBall = false,
    this.maskRedFace = false,
  });

  /// Where the page starts scrolled, so a copy pushed on top of itself
  /// lines up exactly with the page underneath.
  final double initialScrollOffset;

  /// How many playground pages are stacked, shown in the title.
  final int depth;

  /// Initial state of the optional mask switches, so a copy keeps them.
  final bool maskBall;
  final bool maskRedFace;

  @override
  State<ReplayPlaygroundScreen> createState() => _ReplayPlaygroundScreenState();
}

class _ReplayPlaygroundScreenState extends State<ReplayPlaygroundScreen>
    with SingleTickerProviderStateMixin {
  static const _boxSize = Size(480, 270);
  static const _ballSize = 28.0;

  late final AnimationController _controller;
  late final _scrollController =
      ScrollController(initialScrollOffset: widget.initialScrollOffset);
  late bool _maskBall = widget.maskBall;
  late bool _maskRedFace = widget.maskRedFace;

  // Transitions offered by the navigation test section: our custom swipe,
  // then Flutter's built-in ones.
  static const _transitions = <String, PageTransitionsBuilder>{
    'Swipe (custom)': SwipePageTransitionsBuilder(),
    'Zoom': ZoomPageTransitionsBuilder(),
    'Zoom (3s)': SlowPageTransitionsBuilder(
      ZoomPageTransitionsBuilder(),
      duration: Duration(seconds: 3),
    ),
    'Fade forwards': FadeForwardsPageTransitionsBuilder(),
    'Predictive back': PredictiveBackPageTransitionsBuilder(),
    'Open upwards': OpenUpwardsPageTransitionsBuilder(),
    'Fade upwards': FadeUpwardsPageTransitionsBuilder(),
    'Cupertino': CupertinoPageTransitionsBuilder(),
  };
  static const _navigationDelay = Duration(seconds: 1);

  /// Name of the transition waiting to start, if any.
  String? _pendingTransition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  /// After [_navigationDelay], pushes another playground on top using
  /// [name]'s transition, scrolled to where this one is at that moment.
  Future<void> _openAgain(String name) async {
    setState(() => _pendingTransition = name);
    // A `ui.*` category is what both the web replay (which drops
    // non-`ui.*`/fetch/xhr categories) and the Android replay (which drops
    // empty categories) put on the replay timeline.
    await Sentry.addBreadcrumb(Breadcrumb(
      category: 'ui.navigation_test',
      message: 'Navigation will be using "$name"',
      data: {
        'transition': name,
        'delay_ms': _navigationDelay.inMilliseconds,
      },
    ));
    await Future<void>.delayed(_navigationDelay);
    if (!mounted) return;
    setState(() => _pendingTransition = null);

    await Navigator.push(
      context,
      TransitionPageRoute<void>(
        transitions: _transitions[name]!,
        settings: const RouteSettings(name: 'ReplayPlayground'),
        builder: (_) => ReplayPlaygroundScreen(
          initialScrollOffset: _scrollController.offset,
          depth: widget.depth + 1,
          maskBall: _maskBall,
          maskRedFace: _maskRedFace,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ball = Container(
      width: _ballSize,
      height: _ballSize,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.depth > 1
              ? 'Replay Playground #${widget.depth}'
              : 'Replay Playground',
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keep this page open for 5+ seconds, then check the replay in '
              'Sentry. Text is masked by default; the items below in RED color '
              'will be masked when asked to be masked.',
            ),
            const SizedBox(height: 12),
            Container(
              width: _boxSize.width,
              height: _boxSize.height,
              color: Colors.red.shade50,
              child: Stack(
                children: [
                  const Positioned(
                    left: 16,
                    top: 16,
                    child: Text(
                      'REAL FLUTTER CONTENT',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Positioned(
                      left: (_boxSize.width - _ballSize) * _controller.value,
                      top: _boxSize.height * 0.65,
                      child: child!,
                    ),
                    child: _maskBall ? SentryMask(ball) : ball,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Mask the ball (SentryMask)'),
              value: _maskBall,
              onChanged: (value) => setState(() => _maskBall = value),
            ),
            const SizedBox(height: 12),
            Container(
              width: _boxSize.width,
              height: _boxSize.height,
              color: Colors.blue.shade50,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _BouncingCube(
                  progress: _controller.value,
                  area: _boxSize,
                  maskRedFace: _maskRedFace,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Mask the red face square (SentryMask)'),
              value: _maskRedFace,
              onChanged: (value) => setState(() => _maskRedFace = value),
            ),
            const SizedBox(height: 12),
            // Text is masked by default: none of these must ever be readable
            // in the replay, including while they scale or spin.
            const _MaskedRedText(),
            const SizedBox(height: 12),
            SizedBox(
              width: _boxSize.width,
              height: 80,
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.scale(
                    // 0.5x..1.5x, one full zoom in/out per loop.
                    scale: 1 + 0.5 * math.sin(2 * math.pi * _controller.value),
                    child: child,
                  ),
                  child: const _MaskedRedText(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Spins in place around its center; tall enough for the full
            // rotation so it doesn't overlap the widgets around it.
            SizedBox(
              width: _boxSize.width,
              height: 320,
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.rotate(
                    angle: 2 * math.pi * _controller.value,
                    child: child,
                  ),
                  child: const _MaskedRedText(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: _boxSize.width,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigation test',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pendingTransition == null
                        ? 'Opens this page again at the same scroll position, '
                            '1 second after the tap.'
                        : 'Opening with "$_pendingTransition" in 1 second...',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in _transitions.keys)
                        ElevatedButton(
                          onPressed: _pendingTransition == null
                              ? () => _openAgain(name)
                              : null,
                          child: Text(name),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const SentryUnmask(
              Text('This text is unmasked (SentryUnmask).'),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 320,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Masked (default)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const SentryUnmask(
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Unmasked (SentryUnmask)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A fake 3D cube (six transformed flat faces, painter's-algorithm sorted)
/// that spins while bouncing around [area]. All faces are green except one
/// red face, which is wrapped in [SentryMask] while [maskRedFace] is on.
class _BouncingCube extends StatelessWidget {
  const _BouncingCube({
    required this.progress,
    required this.area,
    required this.maskRedFace,
  });

  static const _cubeSize = 70.0;
  // Room for the rotated, perspective-projected cube.
  static const _slotSize = 140.0;

  final double progress;
  final Size area;
  final bool maskRedFace;

  @override
  Widget build(BuildContext context) {
    const half = _cubeSize / 2;
    final turn = 2 * math.pi * progress;
    // Integer multiples of a full turn keep the loop seamless.
    final rotation = Matrix4.identity()
      ..rotateX(turn)
      ..rotateY(2 * turn);
    final perspective = Matrix4.identity()..setEntry(3, 2, 0.002);

    final faces = <(Matrix4, Widget)>[
      (Matrix4.translationValues(0, 0, -half), _face(Colors.red)),
      (
        Matrix4.translationValues(0, 0, half)..rotateY(math.pi),
        _face(Colors.green.shade400),
      ),
      (
        Matrix4.translationValues(half, 0, 0)..rotateY(math.pi / 2),
        _face(Colors.green.shade500),
      ),
      (
        Matrix4.translationValues(-half, 0, 0)..rotateY(-math.pi / 2),
        _face(Colors.green.shade600),
      ),
      (
        Matrix4.translationValues(0, -half, 0)..rotateX(math.pi / 2),
        _face(Colors.green.shade700),
      ),
      (
        Matrix4.translationValues(0, half, 0)..rotateX(-math.pi / 2),
        _face(Colors.green.shade800),
      ),
    ].map((face) => (rotation * face.$1 as Matrix4, face.$2)).toList()
      // Positive z is away from the viewer: paint far faces first.
      ..sort(
          (a, b) => b.$1.getTranslation().z.compareTo(a.$1.getTranslation().z));

    // Ping-pong horizontally, bounce three times per loop vertically.
    final x = 1 - (2 * progress - 1).abs();
    final bounce = math.sin(3 * math.pi * progress).abs();

    return Stack(
      children: [
        Positioned(
          left: (area.width - _slotSize) * x,
          top: (area.height - _slotSize) * (1 - bounce),
          width: _slotSize,
          height: _slotSize,
          child: Center(
            child: SizedBox.square(
              dimension: _cubeSize,
              child: Stack(
                children: [
                  for (final (matrix, face) in faces)
                    Transform(
                      alignment: Alignment.center,
                      transform: perspective * matrix as Matrix4,
                      child: face,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _face(Color color) {
    final face = Container(
      width: _cubeSize,
      height: _cubeSize,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26),
      ),
    );
    return color == Colors.red && maskRedFace ? SentryMask(face) : face;
  }
}

/// Red on screen, but styled black: replay masks take the masked [Text]'s
/// style color, so this gets a black mask, and any red peeking out from
/// under it in a replay is a leak.
class _MaskedRedText extends StatelessWidget {
  const _MaskedRedText();

  static const _maskedTextStyle = TextStyle(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 20,
  );

  @override
  Widget build(BuildContext context) => const ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.red, BlendMode.srcIn),
        child: Text('This text should be masked', style: _maskedTextStyle),
      );
}
