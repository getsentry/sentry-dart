import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Keeps raster work in the home page's first frame.
class AppStartWorkloadBackground extends StatelessWidget {
  const AppStartWorkloadBackground({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (enabled)
        IgnorePointer(child: CustomPaint(painter: _BlurredLayersPainter())),
    ],
  );
}

/// Describes the configured workloads and eagerly lays out sample rows.
class AppStartWorkloadSection extends StatelessWidget {
  const AppStartWorkloadSection({
    super.key,
    this.prolongAttachment = true,
    this.prolongBuild = true,
    this.prolongRaster = true,
  });

  final bool prolongAttachment;
  final bool prolongBuild;
  final bool prolongRaster;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App-start workloads',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Root Widget Attachment: ${prolongAttachment ? "on" : "off"}'),
          Text('Frame Build: ${prolongBuild ? "on" : "off"}'),
          Text('Frame Rasterization: ${prolongRaster ? "on" : "off"}'),
          const SizedBox(height: 8),
          const Text(
            'Configure in app_config.dart, then rebuild and cold-launch. These workloads run during startup.',
          ),
          if (prolongBuild) ...[
            const SizedBox(height: 12),
            // The outer home scroll view eagerly lays out this section, even
            // below the viewport. The inner column lays out all 1,800 rows.
            SizedBox(
              height: 96,
              child: SingleChildScrollView(
                primary: false,
                child: Column(children: List.generate(1800, _product)),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _product(int index) => Padding(
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        const Icon(Icons.shopping_bag, size: 20),
        Expanded(child: Text('Product $index — price and availability')),
      ],
    ),
  );
}

class _BlurredLayersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final layerPaint = Paint()
      // Nonzero alpha keeps the blur passes visible to the renderer while
      // making their combined contribution barely noticeable on screen.
      ..color = const Color(0x01ffffff)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12);
    final circlePaint = Paint();
    // Full-size translucent layers require offscreen rendering and blur passes.
    // Recording these commands also costs some framework paint time.
    for (var layer = 0; layer < 18; layer++) {
      canvas.saveLayer(Offset.zero & size, layerPaint);
      for (var circle = 0; circle < 180; circle++) {
        circlePaint.color = Color.fromARGB(
          90,
          (circle * 29) % 255,
          (layer * 41) % 255,
          190,
        );
        canvas.drawCircle(
          Offset(
            (circle * 47 + layer * 23) % size.width,
            (circle * 73 + layer * 31) % size.height,
          ),
          24 + (circle % 20).toDouble(),
          circlePaint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BlurredLayersPainter oldDelegate) => false;
}
