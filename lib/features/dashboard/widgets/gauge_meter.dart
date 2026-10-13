import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../theme/app_theme.dart';

/// Sales-target gauge — pixel-faithful port of
/// `client/src/app/(app)/dashboard/_components/gauge-meter.tsx`.
class GaugeMeter extends StatelessWidget {
  const GaugeMeter({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    required this.onTargetSave,
  });

  final double currentAmount;
  final double targetAmount;
  final ValueChanged<double> onTargetSave;

  double get percentage => targetAmount > 0
      ? math.min((currentAmount / targetAmount) * 100, 100)
      : 0;

  static const List<_ColorStop> _stops = [
    _ColorStop(0, 239, 68, 68),
    _ColorStop(20, 249, 115, 22),
    _ColorStop(40, 234, 179, 8),
    _ColorStop(60, 132, 204, 22),
    _ColorStop(80, 22, 163, 74),
  ];

  static Color colorFor(double pct) {
    for (var i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i];
      final b = _stops[i + 1];
      if (pct <= b.pct) {
        final t = (pct - a.pct) / (b.pct - a.pct);
        return Color.fromARGB(
          255,
          (a.r + (b.r - a.r) * t).round(),
          (a.g + (b.g - a.g) * t).round(),
          (a.b + (b.b - a.b) * t).round(),
        );
      }
    }
    final last = _stops.last;
    return Color.fromARGB(255, last.r, last.g, last.b);
  }

  static String statusLabel(double pct) {
    if (pct >= 100) return 'Target Achieved!';
    if (pct >= 80) return 'Almost There';
    if (pct >= 60) return 'Good Progress';
    if (pct >= 40) return 'On Track';
    if (pct >= 20) return 'Getting Started';
    return 'Just Started';
  }

  String formatCompact(num val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return grouped(val);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 210,
            height: 158,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percentage),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, pct, _) => CustomPaint(
                painter: _GaugePainter(pct),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (context) {
                    final pct = percentage;
                    final color = colorFor(pct);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel(pct),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PKR ${formatCompact(currentAmount)} / ${formatCompact(targetAmount)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.2,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          _DashedButton(
            label: 'Set Target',
            icon: Icons.gps_fixed,
            onPressed: () => _showTargetDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showTargetDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: targetAmount > 0 ? targetAmount.toString() : '',
    );
    final saved = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void save() {
            final value = double.tryParse(controller.text.trim());
            if (value != null && value > 0) Navigator.pop(context, value);
          }

          return AlertDialog(
            title: const Text('Set Collection Target'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Target Amount (PKR)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  onSubmitted: (_) => save(),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(hintText: 'e.g. 500000.00'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the total collection target. Supports decimal points.',
                  style: TextStyle(fontSize: 11, color: context.mutedFg),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Save Target'),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (saved != null) onTargetSave(saved);
    controller.dispose();
  }
}

class _ColorStop {
  const _ColorStop(this.pct, this.r, this.g, this.b);

  final double pct;
  final int r;
  final int g;
  final int b;
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.percent);

  final double percent;

  static const double _cx = 100;
  static const double _cy = 108;
  static const double _outerR = 68;
  static const double _innerR = 8;
  static const double _startAngle = -210;
  static const double _endAngle = 30;
  static const double _totalAngle = _endAngle - _startAngle;
  static const int _segments = 60;

  static const List<int> _majorTicks = [0, 20, 40, 60, 80, 100];
  static const List<int> _midTicks = [10, 30, 50, 70, 90];

  (double, double) _polar(double angleDeg, double radius) {
    final rad = angleDeg * math.pi / 180;
    return (_cx + radius * math.cos(rad), _cy + radius * math.sin(rad));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient arc — each segment coloured by its exact % position.
    final midR = (_outerR + _innerR) / 2;
    final strokeW = _outerR - _innerR;
    for (var i = 0; i < _segments; i++) {
      final fromPct = (i / _segments) * 100;
      final toPct = ((i + 1) / _segments) * 100;
      final midPct = (fromPct + toPct) / 2;
      final a1 = _startAngle + (fromPct / 100) * _totalAngle;
      final a2 = _startAngle + (toPct / 100) * _totalAngle;
      final paint = Paint()
        ..color = GaugeMeter.colorFor(midPct)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      final rect = Rect.fromCircle(
        center: const Offset(_cx, _cy),
        radius: midR,
      );
      canvas.drawArc(
        rect,
        a1 * math.pi / 180,
        (a2 - a1) * math.pi / 180,
        false,
        paint,
      );
    }

    // Calibration ticks
    for (var tick = 0; tick <= 100; tick++) {
      final angle = _startAngle + (tick / 100) * _totalAngle;
      final len = _majorTicks.contains(tick)
          ? 16.0
          : _midTicks.contains(tick)
          ? 10.0
          : 5.0;
      final width = _majorTicks.contains(tick)
          ? 2.0
          : _midTicks.contains(tick)
          ? 1.5
          : 0.8;
      final tipR = _outerR - 1;
      final (tx, ty) = _polar(angle, tipR);
      final (bx, by) = _polar(angle, tipR - len);
      final paint = Paint()
        ..color = const Color(0xFF1F2937)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(tx, ty), Offset(bx, by), paint);
    }

    // Major tick labels
    for (final tick in _majorTicks) {
      final angle = _startAngle + (tick / 100) * _totalAngle;
      final (x, y) = _polar(angle, _outerR + 14);
      final tp = TextPainter(
        text: TextSpan(
          text: '$tick',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // Needle
    final needleAngle = _startAngle + (percent / 100) * _totalAngle;
    final (tipX, tipY) = _polar(needleAngle, _outerR + 2);
    final (b1x, b1y) = _polar(needleAngle + 90, 8);
    final (b2x, b2y) = _polar(needleAngle - 90, 8);
    final needle = Paint()
      ..color = const Color(0xFF1F2937)
      ..filterQuality = FilterQuality.low;
    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(b1x, b1y)
      ..lineTo(_cx, _cy)
      ..lineTo(b2x, b2y)
      ..close();
    canvas.drawShadow(path, Colors.black, 1, false);
    canvas.drawPath(path, needle);

    // Centre hub
    canvas.drawCircle(
      const Offset(_cx, _cy),
      7,
      Paint()..color = const Color(0xFF374151),
    );
    canvas.drawCircle(
      const Offset(_cx, _cy),
      4.5,
      Paint()..color = const Color(0xFF6B7280),
    );
    canvas.drawCircle(
      const Offset(_cx, _cy),
      2,
      Paint()..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.percent != percent;
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(context.line),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: context.fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
