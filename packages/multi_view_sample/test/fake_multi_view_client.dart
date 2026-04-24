import 'package:multi_view_sample/src/multi_view_sample_controller.dart';

class FakeMultiViewClient implements MultiViewClient {
  int _nextViewId = 1;
  final Set<int> _registered = <int>{0};
  final List<MultiViewRequest> addedRequests = <MultiViewRequest>[];
  final List<int> removedViewIds = <int>[];

  @override
  Future<int> addView(MultiViewRequest request) async {
    final int viewId = _nextViewId++;
    _registered.add(viewId);
    addedRequests.add(request);
    return viewId;
  }

  @override
  List<int> registeredViewIds() => _registered.toList()..sort();

  @override
  Future<bool> removeView(int viewId) async {
    removedViewIds.add(viewId);
    return _registered.remove(viewId);
  }
}
