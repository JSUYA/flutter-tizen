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
  late final MultiViewStageMapper _stageMapper = MultiViewStageMapper();
  late final MultiViewSampleController _controller = MultiViewSampleController(
    client: TizenSampleMultiViewClient(stageMapper: _stageMapper),
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
              child: MultiViewSampleApp(
                controller: _controller,
                stageMapper: _stageMapper,
              ),
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
  const MultiViewSampleApp({
    super.key,
    this.controller,
    this.stageMapper,
    this.autoRun = false,
  });

  final MultiViewSampleController? controller;
  final MultiViewStageMapper? stageMapper;
  final bool autoRun;

  @override
  State<MultiViewSampleApp> createState() => _MultiViewSampleAppState();
}

class _MultiViewSampleAppState extends State<MultiViewSampleApp> {
  late final MultiViewStageMapper _stageMapper =
      widget.stageMapper ?? MultiViewStageMapper();
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
              Expanded(
                child: _StagePanel(
                  controller: controller,
                  stageMapper: stageMapper,
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

const double _stageDragHandleSize = 38;
const double _stageDragHandleGap = 6;
const double _stageDragHandleRailHeight =
    _stageDragHandleSize + _stageDragHandleGap;

class _StagePanel extends StatelessWidget {
  const _StagePanel({required this.controller, required this.stageMapper});

  final MultiViewSampleController controller;
  final MultiViewStageMapper stageMapper;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff3f6f9),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double availableHeight = math.max(
            1,
            constraints.maxHeight - _stageDragHandleRailHeight,
          );
          final double scale = math.min(
            constraints.maxWidth / sampleStageSize.width,
            availableHeight / sampleStageSize.height,
          );
          final Size stage = sampleStageSize * scale;
          return Center(
            child: SizedBox(
              width: stage.width,
              height: stage.height + _stageDragHandleRailHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    top: _stageDragHandleRailHeight,
                    left: 0,
                    width: stage.width,
                    height: stage.height,
                    child: _StageViewportReporter(
                      stageMapper: stageMapper,
                      stageScale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xffc7d0da)),
                        ),
                        child: const Stack(
                          children: <Widget>[
                            Positioned.fill(child: _StageGrid()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final SampleViewSpec spec in controller.views)
                    if (spec.viewId != null)
                      Positioned.fill(
                        child: _StageViewChrome(
                          key: ValueKey<String>('chrome-${spec.localId}'),
                          controller: controller,
                          spec: spec,
                          stageScale: scale,
                          stageTop: _stageDragHandleRailHeight,
                        ),
                      ),
                ],
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

class _StageViewChrome extends StatefulWidget {
  const _StageViewChrome({
    super.key,
    required this.controller,
    required this.spec,
    required this.stageScale,
    required this.stageTop,
  });

  final MultiViewSampleController controller;
  final SampleViewSpec spec;
  final double stageScale;
  final double stageTop;

  @override
  State<_StageViewChrome> createState() => _StageViewChromeState();
}

class _StageViewChromeState extends State<_StageViewChrome> {
  Rect? _dragStartGeometry;
  Offset? _dragStartGlobalPosition;
  int? _dragPointer;
  bool _dragMoved = false;

  bool get _enabled =>
      !widget.controller.busy &&
      !widget.controller.runningScript &&
      !widget.spec.busy &&
      widget.spec.viewId != null;

  @override
  Widget build(BuildContext context) {
    final Rect geometry = widget.spec.geometry;
    final double scale = widget.stageScale;
    final double stageWidth = sampleStageSize.width * scale;
    final double outlineLeft = geometry.left * scale;
    final double outlineTop = widget.stageTop + geometry.top * scale;
    final double outlineWidth = geometry.width * scale;
    final double outlineHeight = geometry.height * scale;
    final double maxHandleLeft = math.max(0, stageWidth - _stageDragHandleSize);
    final double handleLeft =
        (geometry.center.dx * scale - _stageDragHandleSize / 2).clamp(
          0.0,
          maxHandleLeft,
        );
    final double handleTop =
        widget.stageTop +
        geometry.top * scale -
        _stageDragHandleSize -
        _stageDragHandleGap;
    final bool selected =
        widget.controller.selectedLocalId == widget.spec.localId;
    final Color color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xff4c5967);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: outlineLeft,
          top: outlineTop,
          width: outlineWidth,
          height: outlineHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? color : const Color(0x994c5967),
                  width: selected ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: handleLeft,
          top: handleTop,
          width: _stageDragHandleSize,
          height: _stageDragHandleSize,
          child: Tooltip(
            message: 'Drag ${widget.spec.kind.label} view',
            child: Semantics(
              button: true,
              label: 'Drag ${widget.spec.kind.label} view',
              child: MouseRegion(
                cursor: _enabled
                    ? SystemMouseCursors.move
                    : SystemMouseCursors.basic,
                child: Listener(
                  key: ValueKey<String>('drag-handle-${widget.spec.localId}'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _enabled ? _handlePointerDown : null,
                  onPointerMove: _enabled ? _handlePointerMove : null,
                  onPointerUp: _enabled ? _handlePointerUp : null,
                  onPointerCancel: _enabled ? _handlePointerCancel : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _enabled ? Colors.white : const Color(0xffd9e0e7),
                      border: Border.all(color: color, width: selected ? 2 : 1),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.open_with,
                      size: 20,
                      color: _enabled ? color : const Color(0xff7b8794),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_dragPointer != null) {
      return;
    }
    _dragPointer = event.pointer;
    _dragMoved = false;
    _dragStartGeometry = widget.spec.geometry;
    _dragStartGlobalPosition = event.position;
    widget.controller.select(widget.spec.localId);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) {
      return;
    }
    if (event.buttons == 0) {
      _finishDrag();
      return;
    }
    final Rect? startGeometry = _dragStartGeometry;
    final Offset? startGlobalPosition = _dragStartGlobalPosition;
    if (startGeometry == null ||
        startGlobalPosition == null ||
        widget.stageScale <= 0) {
      return;
    }
    final Offset stageDelta =
        (event.position - startGlobalPosition) / widget.stageScale;
    if (stageDelta.distance < 0.5) {
      return;
    }
    _dragMoved = true;
    widget.controller.dragViewTo(
      widget.spec.localId,
      startGeometry.shift(stageDelta),
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer == _dragPointer) {
      _finishDrag();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _dragPointer) {
      _finishDrag();
    }
  }

  void _finishDrag() {
    if (_dragStartGeometry == null) {
      return;
    }
    final bool moved = _dragMoved;
    _dragStartGeometry = null;
    _dragStartGlobalPosition = null;
    _dragPointer = null;
    _dragMoved = false;
    if (moved) {
      widget.controller.finishDrag(widget.spec.localId);
    }
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
                  onPressed: controller.busy || controller.runningScript
                      ? null
                      : () => unawaited(controller.addPreset(kind)),
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
                  onPressed: controller.runningScript || controller.busy
                      ? null
                      : () => unawaited(controller.runStressScenario()),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Demo'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Reset',
                onPressed: controller.busy
                    ? null
                    : () => unawaited(controller.resetShowcase()),
                icon: const Icon(Icons.dashboard_customize_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Clear',
                onPressed: controller.busy
                    ? null
                    : () => unawaited(controller.clearAll()),
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
  final VoidCallback? onPressed;

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
    final bool enabled = !controller.busy && !controller.runningScript;
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
                onPressed: enabled
                    ? () => unawaited(
                        controller.move(view.localId, const Offset(0, -32)),
                      )
                    : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton.filledTonal(
                tooltip: 'Move left',
                onPressed: enabled
                    ? () => unawaited(
                        controller.move(view.localId, const Offset(-32, 0)),
                      )
                    : null,
                icon: const Icon(Icons.keyboard_arrow_left),
              ),
              IconButton.filledTonal(
                tooltip: 'Move right',
                onPressed: enabled
                    ? () => unawaited(
                        controller.move(view.localId, const Offset(32, 0)),
                      )
                    : null,
                icon: const Icon(Icons.keyboard_arrow_right),
              ),
              IconButton.filledTonal(
                tooltip: 'Move down',
                onPressed: enabled
                    ? () => unawaited(
                        controller.move(view.localId, const Offset(0, 32)),
                      )
                    : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton.filledTonal(
                tooltip: 'Grow',
                onPressed: enabled
                    ? () => unawaited(controller.resize(view.localId, 1.12))
                    : null,
                icon: const Icon(Icons.zoom_out_map),
              ),
              IconButton.filledTonal(
                tooltip: 'Shrink',
                onPressed: enabled
                    ? () => unawaited(controller.resize(view.localId, 0.88))
                    : null,
                icon: const Icon(Icons.zoom_in_map),
              ),
              IconButton.filledTonal(
                tooltip: 'Duplicate',
                onPressed: enabled
                    ? () => unawaited(controller.duplicate(view.localId))
                    : null,
                icon: const Icon(Icons.control_point_duplicate_outlined),
              ),
              IconButton.filled(
                tooltip: 'Remove',
                onPressed: enabled
                    ? () => unawaited(controller.remove(view.localId))
                    : null,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
