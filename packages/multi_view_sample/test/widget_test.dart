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
}
