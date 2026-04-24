import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_view_sample/src/multi_view_sample_controller.dart';
import 'package:multi_view_sample/src/secondary_view_content.dart';

const bool _autoRun = bool.fromEnvironment(
  'MULTI_VIEW_SAMPLE_AUTORUN',
  defaultValue: false,
);

void runMultiViewSample() {
  WidgetsFlutterBinding.ensureInitialized();
  runWidget(const MultiViewSampleRoot(autoRun: _autoRun));
}

class MultiViewSampleRoot extends StatefulWidget {
  const MultiViewSampleRoot({super.key, this.autoRun = false});

  final bool autoRun;

  @override
  State<MultiViewSampleRoot> createState() => _MultiViewSampleRootState();
}

class _MultiViewSampleRootState extends State<MultiViewSampleRoot> {
  late final MultiViewSampleController _controller = MultiViewSampleController(
    client: const TizenSampleMultiViewClient(),
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runAutomatedScenario());
      });
    }
  }

  Future<void> _runAutomatedScenario() async {
    try {
      debugPrint('MULTIVIEW_SAMPLE_AUTORUN start');
      await _controller.runStressScenario(cycles: 10);
      debugPrint(
        'MULTIVIEW_SAMPLE_AUTORUN complete '
        'registered=${_controller.registeredViewIds()}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await SystemNavigator.pop();
    } catch (error, stackTrace) {
      debugPrint('MULTIVIEW_SAMPLE_AUTORUN failure=$error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final ui.FlutterView? implicitView =
            WidgetsBinding.instance.platformDispatcher.implicitView;
        final List<Widget> views = <Widget>[
          if (implicitView != null)
            View(
              view: implicitView,
              child: MultiViewSampleApp(controller: _controller),
            ),
          for (final SampleViewSpec spec in _controller.views)
            if (spec.viewId case final int viewId)
              if (WidgetsBinding.instance.platformDispatcher.view(id: viewId)
                  case final ui.FlutterView flutterView)
                View(
                  key: ValueKey<String>(
                    'secondary-${spec.localId}-$viewId-${spec.generation}',
                  ),
                  view: flutterView,
                  child: SecondaryViewContent(spec: spec),
                ),
        ];
        return ViewCollection(views: views);
      },
    );
  }
}

class MultiViewSampleApp extends StatefulWidget {
  const MultiViewSampleApp({super.key, this.controller, this.autoRun = false});

  final MultiViewSampleController? controller;
  final bool autoRun;

  @override
  State<MultiViewSampleApp> createState() => _MultiViewSampleAppState();
}

class _MultiViewSampleAppState extends State<MultiViewSampleApp> {
  late final MultiViewSampleController _controller =
      widget.controller ??
      MultiViewSampleController(client: const TizenSampleMultiViewClient());
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runAutomatedScenario());
      });
    }
  }

  Future<void> _runAutomatedScenario() async {
    try {
      debugPrint('MULTIVIEW_SAMPLE_AUTORUN start');
      await _controller.runStressScenario(cycles: 10);
      debugPrint(
        'MULTIVIEW_SAMPLE_AUTORUN complete '
        'registered=${_controller.registeredViewIds()}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await SystemNavigator.pop();
    } catch (error, stackTrace) {
      debugPrint('MULTIVIEW_SAMPLE_AUTORUN failure=$error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2f80ed),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: MultiViewSampleHome(controller: _controller),
    );
  }
}

class MultiViewSampleHome extends StatelessWidget {
  const MultiViewSampleHome({super.key, required this.controller});

  final MultiViewSampleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final SampleViewSpec? selected = controller.selectedView;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tizen Multi-view Sample'),
            actions: <Widget>[
              _Metric(label: 'Views', value: '${controller.views.length}'),
              _Metric(
                label: 'Registered',
                value: controller.registeredViewIds().join(', '),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Row(
            children: <Widget>[
              Expanded(
                child: _StagePanel(
                  controller: controller,
                  selectedLocalId: selected?.localId,
                ),
              ),
              SizedBox(
                width: 360,
                child: _ControlPanel(
                  controller: controller,
                  selected: selected,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            value.isEmpty ? '-' : value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _StagePanel extends StatelessWidget {
  const _StagePanel({required this.controller, required this.selectedLocalId});

  final MultiViewSampleController controller;
  final String? selectedLocalId;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff3f6f9),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double scale = math.min(
            constraints.maxWidth / sampleStageSize.width,
            constraints.maxHeight / sampleStageSize.height,
          );
          final Size stage = sampleStageSize * scale;
          return Center(
            child: SizedBox(
              width: stage.width,
              height: stage.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffc7d0da)),
                ),
                child: Stack(
                  children: <Widget>[
                    const Positioned.fill(child: _StageGrid()),
                    for (final SampleViewSpec view in controller.views)
                      Positioned(
                        left: view.geometry.left * scale,
                        top: view.geometry.top * scale,
                        width: view.geometry.width * scale,
                        height: view.geometry.height * scale,
                        child: _ViewTile(
                          view: view,
                          selected: view.localId == selectedLocalId,
                          onTap: () => controller.select(view.localId),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StageGrid extends StatelessWidget {
  const _StageGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StageGridPainter());
  }
}

class _StageGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = const Color(0xffe4e9ef)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += size.width / 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += size.height / 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_StageGridPainter oldDelegate) => false;
}

class _ViewTile extends StatelessWidget {
  const _ViewTile({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final SampleViewSpec view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = view.kind.color;
    return Material(
      color: color.withValues(alpha: view.transparent ? 0.44 : 0.88),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.black : color.darken(),
              width: selected ? 3 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: selected ? 18 : 8,
                color: Colors.black.withValues(alpha: selected ? 0.24 : 0.12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact =
                  constraints.maxWidth < 150 || constraints.maxHeight < 90;
              return DefaultTextStyle(
                style: TextStyle(
                  color: color.computeLuminance() > 0.62
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(view.kind.icon, size: compact ? 16 : 22),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            view.kind.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...<Widget>[
                      const Spacer(),
                      Text('viewId ${view.viewId ?? '-'}'),
                      Text(
                        '${view.geometry.width.round()} x '
                        '${view.geometry.height.round()}',
                      ),
                      Text('dpr ${view.userPixelRatio} gen ${view.generation}'),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.controller, required this.selected});

  final MultiViewSampleController controller;
  final SampleViewSpec? selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xfffbfcfd),
        border: Border(left: BorderSide(color: Color(0xffd7dde3))),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Add view', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SampleViewKind kind in SampleViewKind.values)
                _PresetButton(
                  kind: kind,
                  onPressed: () => unawaited(controller.addPreset(kind)),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('Selected', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (selected == null)
            const Text('No view selected')
          else
            _SelectedControls(controller: controller, view: selected!),
          const Divider(height: 32),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.runningScript
                      ? null
                      : () => unawaited(controller.runStressScenario()),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Demo'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Reset',
                onPressed: () => unawaited(controller.resetShowcase()),
                icon: const Icon(Icons.dashboard_customize_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Clear',
                onPressed: () => unawaited(controller.clearAll()),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Event log', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final String event in controller.events.take(18))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(event, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.kind, required this.onPressed});

  final SampleViewKind kind;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(kind.icon),
        label: Text(kind.label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SelectedControls extends StatelessWidget {
  const _SelectedControls({required this.controller, required this.view});

  final MultiViewSampleController controller;
  final SampleViewSpec view;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('${view.kind.label}  viewId ${view.viewId ?? '-'}'),
        Text(
          '${view.geometry.left.round()}, ${view.geometry.top.round()}  '
          '${view.geometry.width.round()} x ${view.geometry.height.round()}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              IconButton.filledTonal(
                tooltip: 'Move up',
                onPressed: () => unawaited(
                  controller.move(view.localId, const Offset(0, -32)),
                ),
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton.filledTonal(
                tooltip: 'Move left',
                onPressed: () => unawaited(
                  controller.move(view.localId, const Offset(-32, 0)),
                ),
                icon: const Icon(Icons.keyboard_arrow_left),
              ),
              IconButton.filledTonal(
                tooltip: 'Move right',
                onPressed: () => unawaited(
                  controller.move(view.localId, const Offset(32, 0)),
                ),
                icon: const Icon(Icons.keyboard_arrow_right),
              ),
              IconButton.filledTonal(
                tooltip: 'Move down',
                onPressed: () => unawaited(
                  controller.move(view.localId, const Offset(0, 32)),
                ),
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton.filledTonal(
                tooltip: 'Grow',
                onPressed: () =>
                    unawaited(controller.resize(view.localId, 1.12)),
                icon: const Icon(Icons.zoom_out_map),
              ),
              IconButton.filledTonal(
                tooltip: 'Shrink',
                onPressed: () =>
                    unawaited(controller.resize(view.localId, 0.88)),
                icon: const Icon(Icons.zoom_in_map),
              ),
              IconButton.filledTonal(
                tooltip: 'Duplicate',
                onPressed: () => unawaited(controller.duplicate(view.localId)),
                icon: const Icon(Icons.control_point_duplicate_outlined),
              ),
              IconButton.filled(
                tooltip: 'Remove',
                onPressed: () => unawaited(controller.remove(view.localId)),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension on Color {
  Color darken() {
    final HSLColor hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
  }
}
