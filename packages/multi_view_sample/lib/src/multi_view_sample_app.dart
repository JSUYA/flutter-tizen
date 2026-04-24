import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_view_sample/src/multi_view_sample_controller.dart';
import 'package:multi_view_sample/src/secondary_view_content.dart';
import 'package:video_player_tizen/video_player_tizen.dart';
import 'package:webview_flutter_tizen/webview_flutter_tizen.dart';

const bool _autoRun = bool.fromEnvironment(
  'MULTI_VIEW_SAMPLE_AUTORUN',
  defaultValue: false,
);
const bool _renderSecondaryWidgets = bool.fromEnvironment(
  'MULTI_VIEW_SAMPLE_RENDER_SECONDARY_WIDGETS',
  defaultValue: true,
);

void runMultiViewSample() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.operatingSystem == 'tizen') {
    VideoPlayerTizen.register();
    TizenWebViewPlatform.register();
  }
  if (_renderSecondaryWidgets) {
    runWidget(const MultiViewSampleRoot(autoRun: _autoRun));
    return;
  }
  runApp(const MultiViewSampleApp(autoRun: _autoRun));
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
                  child: _SecondaryViewHost(spec: spec),
                ),
        ];
        return ViewCollection(views: views);
      },
    );
  }
}

class _SecondaryViewHost extends StatelessWidget {
  const _SecondaryViewHost({required this.spec});

  final SampleViewSpec spec;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SecondaryViewContent(spec: spec),
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
  late final MultiViewStageMapper _stageMapper = MultiViewStageMapper();
  late final MultiViewSampleController _controller =
      widget.controller ??
      MultiViewSampleController(
        client: TizenSampleMultiViewClient(stageMapper: _stageMapper),
      );
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
      await WidgetsBinding.instance.endOfFrame;
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
      home: MultiViewSampleHome(
        controller: _controller,
        stageMapper: _stageMapper,
      ),
    );
  }
}

class MultiViewSampleHome extends StatelessWidget {
  const MultiViewSampleHome({
    super.key,
    required this.controller,
    required this.stageMapper,
  });

  final MultiViewSampleController controller;
  final MultiViewStageMapper stageMapper;

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
              Expanded(child: _StagePanel(stageMapper: stageMapper)),
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
  const _StagePanel({required this.stageMapper});

  final MultiViewStageMapper stageMapper;

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
            child: _StageViewportReporter(
              stageMapper: stageMapper,
              stageScale: scale,
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
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StageViewportReporter extends StatefulWidget {
  const _StageViewportReporter({
    required this.stageMapper,
    required this.stageScale,
    required this.child,
  });

  final MultiViewStageMapper stageMapper;
  final double stageScale;
  final Widget child;

  @override
  State<_StageViewportReporter> createState() => _StageViewportReporterState();
}

class _StageViewportReporterState extends State<_StageViewportReporter> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportViewport());
    return KeyedSubtree(key: _key, child: widget.child);
  }

  void _reportViewport() {
    if (!mounted) {
      return;
    }
    final BuildContext? keyContext = _key.currentContext;
    final RenderObject? renderObject = keyContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    widget.stageMapper.update(
      stageOrigin: renderObject.localToGlobal(Offset.zero),
      stageSize: renderObject.size,
      stageScale: widget.stageScale,
      devicePixelRatio: View.of(context).devicePixelRatio,
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
          if (controller.views.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final SampleViewSpec view in controller.views)
                  ChoiceChip(
                    selected: view.localId == selected?.localId,
                    avatar: Icon(view.kind.icon, size: 18),
                    label: Text('${view.kind.label} ${view.viewId ?? '-'}'),
                    onSelected: (_) => controller.select(view.localId),
                  ),
              ],
            ),
          ],
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
