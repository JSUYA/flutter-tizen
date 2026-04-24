import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tizen/flutter_tizen.dart';

const Size sampleStageSize = Size(1280, 720);

enum SampleViewKind {
  dashboard,
  chart,
  video,
  inspector,
  banner,
  transparent,
  mini,
}

extension SampleViewKindInfo on SampleViewKind {
  String get label {
    switch (this) {
      case SampleViewKind.dashboard:
        return 'Dashboard';
      case SampleViewKind.chart:
        return 'Chart';
      case SampleViewKind.video:
        return 'Video';
      case SampleViewKind.inspector:
        return 'Inspector';
      case SampleViewKind.banner:
        return 'Banner';
      case SampleViewKind.transparent:
        return 'Overlay';
      case SampleViewKind.mini:
        return 'Mini';
    }
  }

  IconData get icon {
    switch (this) {
      case SampleViewKind.dashboard:
        return Icons.space_dashboard_outlined;
      case SampleViewKind.chart:
        return Icons.insert_chart_outlined;
      case SampleViewKind.video:
        return Icons.smart_display_outlined;
      case SampleViewKind.inspector:
        return Icons.manage_search_outlined;
      case SampleViewKind.banner:
        return Icons.call_to_action_outlined;
      case SampleViewKind.transparent:
        return Icons.layers_outlined;
      case SampleViewKind.mini:
        return Icons.widgets_outlined;
    }
  }

  Color get color {
    switch (this) {
      case SampleViewKind.dashboard:
        return const Color(0xff2f80ed);
      case SampleViewKind.chart:
        return const Color(0xff27ae60);
      case SampleViewKind.video:
        return const Color(0xffeb5757);
      case SampleViewKind.inspector:
        return const Color(0xff9b51e0);
      case SampleViewKind.banner:
        return const Color(0xfff2994a);
      case SampleViewKind.transparent:
        return const Color(0xff56ccf2);
      case SampleViewKind.mini:
        return const Color(0xfff2c94c);
    }
  }

  bool get defaultTransparent => this == SampleViewKind.transparent;

  double get defaultPixelRatio {
    switch (this) {
      case SampleViewKind.video:
        return 1.5;
      case SampleViewKind.mini:
        return 2.0;
      case SampleViewKind.dashboard:
      case SampleViewKind.chart:
      case SampleViewKind.inspector:
      case SampleViewKind.banner:
      case SampleViewKind.transparent:
        return 0.0;
    }
  }
}

@immutable
class MultiViewRequest {
  const MultiViewRequest({
    required this.geometry,
    required this.transparent,
    required this.userPixelRatio,
  });

  final Rect geometry;
  final bool transparent;
  final double userPixelRatio;
}

abstract class MultiViewClient {
  Future<int> addView(MultiViewRequest request);
  Future<bool> removeView(int viewId);
  List<int> registeredViewIds();
}

class TizenSampleMultiViewClient implements MultiViewClient {
  const TizenSampleMultiViewClient();

  @override
  Future<int> addView(MultiViewRequest request) async {
    final TizenViewHandle handle = await TizenMultiView.addView(
      x: request.geometry.left.round(),
      y: request.geometry.top.round(),
      width: request.geometry.width.round(),
      height: request.geometry.height.round(),
      transparent: request.transparent,
      userPixelRatio: request.userPixelRatio,
    );
    return handle.viewId;
  }

  @override
  List<int> registeredViewIds() =>
      TizenMultiView.registeredViewIds.toList()..sort();

  @override
  Future<bool> removeView(int viewId) => TizenMultiView.removeView(viewId);
}

@immutable
class SampleViewSpec {
  const SampleViewSpec({
    required this.localId,
    required this.title,
    required this.kind,
    required this.geometry,
    required this.transparent,
    required this.userPixelRatio,
    required this.generation,
    this.viewId,
    this.busy = false,
  });

  final String localId;
  final String title;
  final SampleViewKind kind;
  final Rect geometry;
  final bool transparent;
  final double userPixelRatio;
  final int generation;
  final int? viewId;
  final bool busy;

  SampleViewSpec copyWith({
    String? title,
    SampleViewKind? kind,
    Rect? geometry,
    bool? transparent,
    double? userPixelRatio,
    int? generation,
    int? viewId,
    bool clearViewId = false,
    bool? busy,
  }) {
    return SampleViewSpec(
      localId: localId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      geometry: geometry ?? this.geometry,
      transparent: transparent ?? this.transparent,
      userPixelRatio: userPixelRatio ?? this.userPixelRatio,
      generation: generation ?? this.generation,
      viewId: clearViewId ? null : viewId ?? this.viewId,
      busy: busy ?? this.busy,
    );
  }

  MultiViewRequest toRequest() {
    return MultiViewRequest(
      geometry: geometry,
      transparent: transparent,
      userPixelRatio: userPixelRatio,
    );
  }
}

class MultiViewSampleController extends ChangeNotifier {
  MultiViewSampleController({
    required this.client,
    this.stageSize = sampleStageSize,
  });

  final MultiViewClient client;
  final Size stageSize;
  final List<SampleViewSpec> _views = <SampleViewSpec>[];
  final List<String> _events = <String>[];
  int _nextLocalId = 1;
  int _eventSerial = 0;
  String? _selectedLocalId;
  bool _runningScript = false;

  List<SampleViewSpec> get views => List<SampleViewSpec>.unmodifiable(_views);
  List<String> get events => List<String>.unmodifiable(_events);
  bool get runningScript => _runningScript;
  String? get selectedLocalId => _selectedLocalId;

  SampleViewSpec? get selectedView {
    for (final SampleViewSpec view in _views) {
      if (view.localId == _selectedLocalId) {
        return view;
      }
    }
    return null;
  }

  List<int> registeredViewIds() => client.registeredViewIds();

  Future<SampleViewSpec> addPreset(
    SampleViewKind kind, {
    Rect? geometry,
  }) async {
    final int serial = _nextLocalId++;
    final String localId = 'view-$serial';
    final SampleViewSpec pending = SampleViewSpec(
      localId: localId,
      title: '${kind.label} $serial',
      kind: kind,
      geometry: _clampRect(geometry ?? _defaultGeometry(kind, _views.length)),
      transparent: kind.defaultTransparent,
      userPixelRatio: kind.defaultPixelRatio,
      generation: 1,
      busy: true,
    );
    _views.add(pending);
    _selectedLocalId = localId;
    _record('add-pending kind=${kind.label} local=$localId');
    try {
      final int viewId = await client.addView(pending.toRequest());
      final SampleViewSpec ready = pending.copyWith(
        viewId: viewId,
        busy: false,
      );
      _replace(ready);
      _selectedLocalId = localId;
      _record(_describe('add', ready));
      return ready;
    } catch (error) {
      _views.removeWhere((SampleViewSpec view) => view.localId == localId);
      _record('add-failed kind=${kind.label} error=$error');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> remove(String localId) async {
    final SampleViewSpec view = _require(localId);
    _replace(view.copyWith(busy: true));
    notifyListeners();
    final int? viewId = view.viewId;
    final bool removed = viewId == null || await client.removeView(viewId);
    if (removed) {
      _views.removeWhere((SampleViewSpec item) => item.localId == localId);
      if (_selectedLocalId == localId) {
        _selectedLocalId = _views.isEmpty ? null : _views.last.localId;
      }
    } else {
      _replace(view.copyWith(busy: false));
    }
    _record('remove local=$localId viewId=$viewId removed=$removed');
    notifyListeners();
  }

  Future<void> move(String localId, Offset delta) async {
    final SampleViewSpec view = _require(localId);
    await _recreate(
      view,
      view.copyWith(geometry: _clampRect(view.geometry.shift(delta))),
      'move dx=${delta.dx.round()} dy=${delta.dy.round()}',
    );
  }

  Future<void> resize(String localId, double scale) async {
    final SampleViewSpec view = _require(localId);
    final Rect geometry = Rect.fromCenter(
      center: view.geometry.center,
      width: (view.geometry.width * scale).clamp(96.0, stageSize.width),
      height: (view.geometry.height * scale).clamp(72.0, stageSize.height),
    );
    await _recreate(
      view,
      view.copyWith(geometry: _clampRect(geometry)),
      'resize scale=${scale.toStringAsFixed(2)}',
    );
  }

  Future<SampleViewSpec> duplicate(String localId) async {
    final SampleViewSpec view = _require(localId);
    return addPreset(
      view.kind,
      geometry: _clampRect(view.geometry.shift(const Offset(36, 28))),
    );
  }

  Future<void> clearAll() async {
    final List<String> ids = _views
        .map((SampleViewSpec view) => view.localId)
        .toList(growable: false);
    for (final String localId in ids.reversed) {
      await remove(localId);
    }
    _selectedLocalId = null;
    _record('clear-all registered=${registeredViewIds()}');
    notifyListeners();
  }

  Future<void> resetShowcase() async {
    await clearAll();
    for (final SampleViewKind kind in SampleViewKind.values) {
      await addPreset(kind);
    }
    _record('reset-showcase count=${_views.length}');
  }

  Future<void> runStressScenario({int cycles = 6}) async {
    if (_runningScript) {
      return;
    }
    _runningScript = true;
    _record('script-start registered=${registeredViewIds()}');
    notifyListeners();
    try {
      await clearAll();
      for (final SampleViewKind kind in SampleViewKind.values) {
        await addPreset(kind);
      }
      _record('script-after-add registered=${registeredViewIds()}');

      if (_views.length >= 3) {
        await move(_views[0].localId, const Offset(72, 44));
        await resize(_views[1].localId, 1.18);
        await duplicate(_views[2].localId);
      }
      _record('script-after-edit registered=${registeredViewIds()}');

      if (_views.length >= 2) {
        await remove(_views[1].localId);
      }
      _record('script-after-partial-remove registered=${registeredViewIds()}');

      for (int cycle = 0; cycle < cycles; cycle += 1) {
        final SampleViewSpec first = await addPreset(
          cycle.isEven ? SampleViewKind.chart : SampleViewKind.transparent,
          geometry: Rect.fromLTWH(
            84 + (cycle * 28),
            424 + ((cycle % 3) * 36),
            210,
            132,
          ),
        );
        final SampleViewSpec second = await addPreset(
          cycle.isEven ? SampleViewKind.mini : SampleViewKind.banner,
          geometry: Rect.fromLTWH(
            760 - (cycle * 18),
            80 + ((cycle % 4) * 42),
            180,
            116,
          ),
        );
        if (cycle.isEven) {
          await move(first.localId, const Offset(24, -18));
          await remove(second.localId);
          await remove(first.localId);
        } else {
          await resize(second.localId, 0.86);
          await remove(first.localId);
          await remove(second.localId);
        }
        _record('script-cycle-$cycle registered=${registeredViewIds()}');
      }

      await clearAll();
      _record('script-complete registered=${registeredViewIds()}');
    } finally {
      _runningScript = false;
      notifyListeners();
    }
  }

  void select(String? localId) {
    _selectedLocalId = localId;
    notifyListeners();
  }

  Rect _defaultGeometry(SampleViewKind kind, int index) {
    switch (kind) {
      case SampleViewKind.dashboard:
        return const Rect.fromLTWH(48, 48, 360, 220);
      case SampleViewKind.chart:
        return const Rect.fromLTWH(448, 76, 310, 210);
      case SampleViewKind.video:
        return const Rect.fromLTWH(792, 48, 390, 246);
      case SampleViewKind.inspector:
        return const Rect.fromLTWH(76, 330, 300, 250);
      case SampleViewKind.banner:
        return const Rect.fromLTWH(428, 346, 472, 126);
      case SampleViewKind.transparent:
        return const Rect.fromLTWH(646, 238, 340, 260);
      case SampleViewKind.mini:
        return Rect.fromLTWH(952 - (index * 8), 510, 180, 132);
    }
  }

  Rect _clampRect(Rect rect) {
    final double width = math.min(rect.width, stageSize.width);
    final double height = math.min(rect.height, stageSize.height);
    final double left = rect.left.clamp(
      0.0,
      math.max(0.0, stageSize.width - width),
    );
    final double top = rect.top.clamp(
      0.0,
      math.max(0.0, stageSize.height - height),
    );
    return Rect.fromLTWH(left, top, width, height);
  }

  Future<void> _recreate(
    SampleViewSpec current,
    SampleViewSpec next,
    String action,
  ) async {
    _replace(current.copyWith(busy: true));
    notifyListeners();
    final int? oldViewId = current.viewId;
    if (oldViewId != null) {
      await client.removeView(oldViewId);
    }
    final int newViewId = await client.addView(next.toRequest());
    final SampleViewSpec ready = next.copyWith(
      viewId: newViewId,
      generation: current.generation + 1,
      busy: false,
    );
    _replace(ready);
    _selectedLocalId = ready.localId;
    _record(
      '$action local=${ready.localId} oldViewId=$oldViewId newViewId=$newViewId',
    );
    notifyListeners();
  }

  SampleViewSpec _require(String localId) {
    return _views.firstWhere((SampleViewSpec view) => view.localId == localId);
  }

  void _replace(SampleViewSpec next) {
    final int index = _views.indexWhere(
      (SampleViewSpec view) => view.localId == next.localId,
    );
    if (index == -1) {
      _views.add(next);
    } else {
      _views[index] = next;
    }
  }

  String _describe(String action, SampleViewSpec view) {
    return '$action local=${view.localId} viewId=${view.viewId} '
        'kind=${view.kind.label} geometry=${_formatRect(view.geometry)} '
        'transparent=${view.transparent} pixelRatio=${view.userPixelRatio}';
  }

  String _formatRect(Rect rect) {
    return '${rect.left.round()},${rect.top.round()} '
        '${rect.width.round()}x${rect.height.round()}';
  }

  void _record(String message) {
    _eventSerial += 1;
    final String entry = '#$_eventSerial $message';
    _events.insert(0, entry);
    if (_events.length > 80) {
      _events.removeRange(80, _events.length);
    }
    debugPrint('MULTIVIEW_SAMPLE_TEST $entry');
  }
}
