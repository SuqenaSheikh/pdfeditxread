import 'package:flutter/material.dart';

class PenStroke {
  PenStroke({required this.points, required this.color, required this.width});

  final List<Offset> points;
  final Color color;
  final double width;
}

/// Freehand drawing layer used while the pen tool is active (FR-11).
class PenOverlay extends StatefulWidget {
  const PenOverlay({
    super.key,
    required this.color,
    required this.enabled,
    required this.strokes,
    required this.onStrokesChanged,
  });

  final Color color;
  final bool enabled;
  final List<PenStroke> strokes;
  final ValueChanged<List<PenStroke>> onStrokesChanged;

  @override
  State<PenOverlay> createState() => _PenOverlayState();
}

class _PenOverlayState extends State<PenOverlay> {
  List<Offset> _current = [];

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          setState(() => _current = [d.localPosition]);
        },
        onPanUpdate: (d) {
          setState(() => _current = [..._current, d.localPosition]);
        },
        onPanEnd: (_) {
          if (_current.length < 2) {
            setState(() => _current = []);
            return;
          }
          final next = [
            ...widget.strokes,
            PenStroke(points: _current, color: widget.color, width: 2.4),
          ];
          widget.onStrokesChanged(next);
          setState(() => _current = []);
        },
        child: CustomPaint(
          painter: _PenPainter(
            strokes: widget.strokes,
            current: _current,
            currentColor: widget.color,
          ),
        ),
      ),
    );
  }
}

class _PenPainter extends CustomPainter {
  _PenPainter({
    required this.strokes,
    required this.current,
    required this.currentColor,
  });

  final List<PenStroke> strokes;
  final List<Offset> current;
  final Color currentColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _draw(canvas, stroke.points, stroke.color, stroke.width);
    }
    if (current.length > 1) {
      _draw(canvas, current, currentColor, 2.4);
    }
  }

  void _draw(Canvas canvas, List<Offset> points, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PenPainter oldDelegate) => true;
}
