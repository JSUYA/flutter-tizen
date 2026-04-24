import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_view_sample/src/multi_view_sample_app.dart';
import 'package:multi_view_sample/src/multi_view_sample_controller.dart';

import 'fake_multi_view_client.dart';

void main() {
  testWidgets('adds a dashboard view from the control panel', (
    WidgetTester tester,
  ) async {
    final MultiViewSampleController controller = MultiViewSampleController(
      client: FakeMultiViewClient(),
    );

    await tester.pumpWidget(MultiViewSampleApp(controller: controller));

    expect(find.text('Tizen Multi-view Sample'), findsOneWidget);
    expect(controller.views, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Dashboard'));
    await tester.pumpAndSettle();

    expect(controller.views, hasLength(1));
    expect(controller.views.single.kind, SampleViewKind.dashboard);
    expect(find.textContaining('viewId 1'), findsWidgets);
  });

  testWidgets('selected view controls keep native registrations balanced', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeMultiViewClient client = FakeMultiViewClient();
    final MultiViewSampleController controller = MultiViewSampleController(
      client: client,
    );

    await tester.pumpWidget(MultiViewSampleApp(controller: controller));
    await tester.tap(find.widgetWithText(FilledButton, 'Dashboard'));
    await tester.pumpAndSettle();

    Future<void> tapControl(String tooltip) async {
      await tester.ensureVisible(find.byTooltip(tooltip));
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
    }

    for (final String tooltip in <String>[
      'Move up',
      'Move left',
      'Move right',
      'Move down',
      'Grow',
      'Shrink',
    ]) {
      await tapControl(tooltip);
      expect(controller.views, hasLength(1), reason: tooltip);
      expect(client.registeredViewIds(), hasLength(2), reason: tooltip);
    }

    await tapControl('Duplicate');
    expect(controller.views, hasLength(2));
    expect(client.registeredViewIds(), hasLength(3));

    await tapControl('Remove');
    expect(controller.views, hasLength(1));
    expect(client.registeredViewIds(), hasLength(2));

    await tapControl('Clear');
    expect(controller.views, isEmpty);
    expect(client.registeredViewIds(), <int>[0]);

    await tapControl('Reset');
    expect(controller.views, hasLength(SampleViewKind.values.length));
    expect(
      client.registeredViewIds(),
      hasLength(SampleViewKind.values.length + 1),
    );
  });
}
