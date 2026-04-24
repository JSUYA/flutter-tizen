import 'package:flutter_test/flutter_test.dart';
import 'package:multi_view_sample/src/multi_view_sample_controller.dart';

import 'fake_multi_view_client.dart';

void main() {
  test('adds, moves, resizes, and removes native views', () async {
    final FakeMultiViewClient client = FakeMultiViewClient();
    final MultiViewSampleController controller = MultiViewSampleController(
      client: client,
    );

    final SampleViewSpec first = await controller.addPreset(
      SampleViewKind.dashboard,
    );
    final SampleViewSpec second = await controller.addPreset(
      SampleViewKind.chart,
    );

    expect(controller.views.map((SampleViewSpec view) => view.viewId), <int>[
      1,
      2,
    ]);
    expect(client.registeredViewIds(), <int>[0, 1, 2]);

    await controller.move(first.localId, const Offset(24, 16));
    expect(client.removedViewIds, contains(1));
    expect(controller.views.first.viewId, 3);
    expect(client.registeredViewIds(), <int>[0, 2, 3]);

    await controller.resize(second.localId, 1.2);
    expect(client.removedViewIds, contains(2));
    expect(controller.views.last.viewId, 4);
    expect(client.registeredViewIds(), <int>[0, 3, 4]);

    await controller.remove(first.localId);
    expect(controller.views.map((SampleViewSpec view) => view.viewId), <int>[
      4,
    ]);
    expect(client.registeredViewIds(), <int>[0, 4]);
  });

  test('stress scenario leaves no secondary views registered', () async {
    final FakeMultiViewClient client = FakeMultiViewClient();
    final MultiViewSampleController controller = MultiViewSampleController(
      client: client,
    );

    await controller.runStressScenario(cycles: 3);

    expect(controller.views, isEmpty);
    expect(client.registeredViewIds(), <int>[0]);
    expect(controller.events.first, contains('script-complete'));
    expect(client.addedRequests.length, greaterThan(10));
    expect(client.removedViewIds.length, client.addedRequests.length);
  });
}
