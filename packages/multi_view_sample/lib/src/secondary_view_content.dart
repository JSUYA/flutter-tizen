import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:multi_view_sample/src/multi_view_sample_controller.dart';

class SecondaryViewContent extends StatelessWidget {
  const SecondaryViewContent({super.key, required this.spec});

  final SampleViewSpec spec;

  @override
  Widget build(BuildContext context) {
    final Color color = spec.kind.color;
    final double progress = _stableProgress(spec);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: color),
          useMaterial3: true,
        ),
        child: Material(
          color: spec.transparent
              ? color.withValues(alpha: 0.32)
              : const Color(0xff101820),
          child: _SecondaryFrame(
            spec: spec,
            progress: progress,
            child: _buildBody(spec, progress),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SampleViewSpec spec, double progress) {
    switch (spec.kind) {
      case SampleViewKind.dashboard:
        return _DashboardView(spec: spec, progress: progress);
      case SampleViewKind.chart:
        return _ChartView(spec: spec, progress: progress);
      case SampleViewKind.video:
        return _VideoView(spec: spec, progress: progress);
      case SampleViewKind.inspector:
        return _InspectorView(spec: spec, progress: progress);
      case SampleViewKind.banner:
        return _BannerView(spec: spec, progress: progress);
      case SampleViewKind.transparent:
        return _OverlayView(spec: spec, progress: progress);
      case SampleViewKind.mini:
        return _MiniView(spec: spec, progress: progress);
    }
  }

  static double _stableProgress(SampleViewSpec spec) {
    int seed = spec.generation * 37 + (spec.viewId ?? 0) * 17;
    for (final int codeUnit in spec.localId.codeUnits) {
      seed = (seed * 31 + codeUnit) & 0x3fffffff;
    }
    return (seed % 1000) / 1000;
  }
}

class _SecondaryFrame extends StatelessWidget {
  const _SecondaryFrame({
    required this.spec,
    required this.progress,
    required this.child,
  });

  final SampleViewSpec spec;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color color = spec.kind.color;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 150 || constraints.maxWidth < 220;
        final double padding = compact ? 8 : 14;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      color.withValues(alpha: spec.transparent ? 0.54 : 0.92),
                      const Color(
                        0xff111827,
                      ).withValues(alpha: spec.transparent ? 0.38 : 0.98),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _MotionGridPainter(progress)),
            ),
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        spec.kind.icon,
                        color: Colors.white,
                        size: compact ? 16 : 22,
                      ),
                      SizedBox(width: compact ? 5 : 8),
                      Expanded(
                        child: Text(
                          spec.kind.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 13 : 18,
                          ),
                        ),
                      ),
                      if (!compact) _Chip(text: '#${spec.viewId ?? '-'}'),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 10),
                  Expanded(child: child),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '${spec.geometry.width.round()} x ${spec.geometry.height.round()}'
                      '  dpr ${spec.userPixelRatio}  gen ${spec.generation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < 260 || constraints.maxHeight < 120;
        final List<_MetricData> metrics = <_MetricData>[
          _MetricData('CPU', 54 + (math.sin(progress * math.pi * 2) * 18)),
          _MetricData('GPU', 64 + (math.cos(progress * math.pi * 2) * 14)),
          _MetricData('MEM', 43 + (math.sin(progress * math.pi * 4) * 10)),
          _MetricData('FPS', 58 + (math.cos(progress * math.pi * 3) * 4)),
        ];
        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: compact ? 2 : 4,
          mainAxisSpacing: compact ? 5 : 8,
          crossAxisSpacing: compact ? 5 : 8,
          childAspectRatio: compact ? 1.7 : 1.1,
          children: <Widget>[
            for (final _MetricData metric in metrics)
              _MetricCard(metric: metric),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);

  final String label;
  final double value;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final double value = metric.value.clamp(0, 100);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 70;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 6 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: compact ? 10 : 13,
                  ),
                ),
                if (!compact) const Spacer(),
                Text(
                  value.round().toString(),
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 17 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!compact)
                  LinearProgressIndicator(
                    value: value / 100,
                    minHeight: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(color: spec.kind.color, progress: progress),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          'Live throughput',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint axis = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    for (int i = 1; i < 5; i += 1) {
      final double y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axis);
    }

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.04),
        ],
      ).createShader(Offset.zero & size);
    final Paint line = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final Path path = Path();
    for (int i = 0; i <= 32; i += 1) {
      final double x = size.width * i / 32;
      final double wave = math.sin((i / 32 + progress) * math.pi * 2);
      final double wave2 = math.cos((i / 12 + progress) * math.pi * 2);
      final double y = size.height * (0.52 - (wave * 0.18) - (wave2 * 0.08));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final Path area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _VideoView extends StatelessWidget {
  const _VideoView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(painter: _VideoBarsPainter(progress: progress)),
        ),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.26),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LinearProgressIndicator(value: 0.68, minHeight: 5),
        ),
      ],
    );
  }
}

class _VideoBarsPainter extends CustomPainter {
  const _VideoBarsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (int i = 0; i < 9; i += 1) {
      final double left = size.width * i / 9;
      final double width = size.width / 9;
      paint.color = Color.lerp(
        const Color(0xffe74c3c),
        const Color(0xff2c3e50),
        (math.sin(progress * math.pi * 2 + i) + 1) / 2,
      )!.withValues(alpha: 0.72);
      canvas.drawRect(Rect.fromLTWH(left, 0, width + 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_VideoBarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _InspectorView extends StatelessWidget {
  const _InspectorView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final List<String> rows = <String>[
      'local: ${spec.localId}',
      'view: ${spec.viewId}',
      'kind: ${spec.kind.label}',
      'left: ${spec.geometry.left.round()}',
      'top: ${spec.geometry.top.round()}',
      'transparent: ${spec.transparent}',
      'generation: ${spec.generation}',
    ];
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (BuildContext context, int index) =>
          Divider(color: Colors.white.withValues(alpha: 0.14), height: 1),
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            rows[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        );
      },
    );
  }
}

class _BannerView extends StatelessWidget {
  const _BannerView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 72 || constraints.maxWidth < 200;
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Multi-view surface ${spec.viewId ?? '-'}',
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 15 : 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: compact ? 6 : 12),
            Transform.rotate(
              angle: progress * math.pi * 2,
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: compact ? 24 : 42,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverlayView extends StatelessWidget {
  const _OverlayView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(painter: _RadarPainter(progress: progress)),
        ),
        Align(
          alignment: Alignment.center,
          child: Text(
            'Transparent overlay',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) * 0.42;
    final Paint ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 1; i <= 4; i += 1) {
      canvas.drawCircle(center, radius * i / 4, ring);
    }
    final Paint sweep = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 3;
    final double angle = progress * math.pi * 2;
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * radius,
      sweep,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MiniView extends StatelessWidget {
  const _MiniView({required this.spec, required this.progress});

  final SampleViewSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: CustomPaint(
            painter: _GaugePainter(
              value: 0.55 + math.sin(progress * math.pi * 2) * 0.22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomPaint(
            painter: _GaugePainter(
              value: 0.52 + math.cos(progress * math.pi * 2) * 0.24,
            ),
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.72);
    final double radius = math.min(size.width, size.height) * 0.42;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint base = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final Paint active = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * value.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) => oldDelegate.value != value;
}

class _MotionGridPainter extends CustomPainter {
  const _MotionGridPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final double offset = progress * 28;
    for (double x = -28 + offset; x < size.width + 28; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -28 + offset; y < size.height + 28; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MotionGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
