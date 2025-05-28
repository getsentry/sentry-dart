import 'package:flutter/material.dart';

class SentryLogo extends StatelessWidget {
  const SentryLogo({super.key, this.width = 50.0});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, (width * 0.88).toDouble()),
      painter: _CustomPainter(),
    );
  }
}

//Copy this CustomPainter code to the Bottom of the File
class _CustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Path path_0 = Path();
    path_0.moveTo(size.width * 0.5800000, size.height * 0.05136364);
    path_0.arcToPoint(Offset(size.width * 0.4200000, size.height * 0.05136364),
        radius:
            Radius.elliptical(size.width * 0.09340000, size.height * 0.1061364),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.lineTo(size.width * 0.2884000, size.height * 0.3075000);
    path_0.arcToPoint(Offset(size.width * 0.6434000, size.height * 0.9134091),
        radius:
            Radius.elliptical(size.width * 0.6442000, size.height * 0.7320455),
        rotation: 0,
        largeArc: false,
        clockwise: true);
    path_0.lineTo(size.width * 0.5510000, size.height * 0.9134091);
    path_0.arcToPoint(Offset(size.width * 0.2418000, size.height * 0.3970455),
        radius:
            Radius.elliptical(size.width * 0.5536000, size.height * 0.6290909),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.lineTo(size.width * 0.1200000, size.height * 0.6363636);
    path_0.arcToPoint(Offset(size.width * 0.3046000, size.height * 0.9129545),
        radius:
            Radius.elliptical(size.width * 0.3184000, size.height * 0.3618182),
        rotation: 0,
        largeArc: false,
        clockwise: true);
    path_0.lineTo(size.width * 0.09240000, size.height * 0.9129545);
    path_0.arcToPoint(Offset(size.width * 0.08000000, size.height * 0.8877273),
        radius: Radius.elliptical(
            size.width * 0.01520000, size.height * 0.01727273),
        rotation: 0,
        largeArc: false,
        clockwise: true);
    path_0.lineTo(size.width * 0.1388000, size.height * 0.7740909);
    path_0.arcToPoint(Offset(size.width * 0.07160000, size.height * 0.7309091),
        radius:
            Radius.elliptical(size.width * 0.2148000, size.height * 0.2440909),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.lineTo(size.width * 0.01340000, size.height * 0.8445455);
    path_0.arcToPoint(Offset(size.width * 0.04720000, size.height * 0.9863636),
        radius:
            Radius.elliptical(size.width * 0.09080000, size.height * 0.1031818),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.arcToPoint(Offset(size.width * 0.09240000, size.height),
        radius:
            Radius.elliptical(size.width * 0.09320000, size.height * 0.1059091),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.lineTo(size.width * 0.3830000, size.height);
    path_0.arcToPoint(Offset(size.width * 0.2230000, size.height * 0.6065909),
        radius:
            Radius.elliptical(size.width * 0.3880000, size.height * 0.4409091),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.lineTo(size.width * 0.2692000, size.height * 0.5156818);
    path_0.arcToPoint(Offset(size.width * 0.4752000, size.height),
        radius:
            Radius.elliptical(size.width * 0.4774000, size.height * 0.5425000),
        rotation: 0,
        largeArc: false,
        clockwise: true);
    path_0.lineTo(size.width * 0.7214000, size.height);
    path_0.arcToPoint(Offset(size.width * 0.3932000, size.height * 0.2772727),
        radius:
            Radius.elliptical(size.width * 0.7176000, size.height * 0.8154545),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.lineTo(size.width * 0.4866000, size.height * 0.09545455);
    path_0.arcToPoint(Offset(size.width * 0.5076000, size.height * 0.08931818),
        radius: Radius.elliptical(
            size.width * 0.01540000, size.height * 0.01750000),
        rotation: 0,
        largeArc: false,
        clockwise: true);
    path_0.cubicTo(
        size.width * 0.5182000,
        size.height * 0.09590909,
        size.width * 0.9134000,
        size.height * 0.8795455,
        size.width * 0.9208000,
        size.height * 0.8886364);
    path_0.arcToPoint(Offset(size.width * 0.9072000, size.height * 0.9143182),
        radius: Radius.elliptical(
            size.width * 0.01520000, size.height * 0.01727273),
        rotation: 0,
        largeArc: false,
        clockwise: true);
    path_0.lineTo(size.width * 0.8120000, size.height * 0.9143182);
    path_0.quadraticBezierTo(size.width * 0.8138000, size.height * 0.9577273,
        size.width * 0.8120000, size.height * 1.000909);
    path_0.lineTo(size.width * 0.9076000, size.height * 1.000909);
    path_0.arcToPoint(Offset(size.width, size.height * 0.8961364),
        radius:
            Radius.elliptical(size.width * 0.09180000, size.height * 0.1043182),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.arcToPoint(Offset(size.width * 0.9876000, size.height * 0.8443182),
        radius:
            Radius.elliptical(size.width * 0.08980000, size.height * 0.1020455),
        rotation: 0,
        largeArc: false,
        clockwise: false);
    path_0.close();

    Paint paint0Fill = Paint()..style = PaintingStyle.fill;
    paint0Fill.color = Color(0xff362d59).withOpacity(1.0);
    canvas.drawPath(path_0, paint0Fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
