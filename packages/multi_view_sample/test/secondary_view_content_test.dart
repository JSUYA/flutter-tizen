import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_view_sample/src/multi_view_sample_controller.dart';
import 'package:multi_view_sample/src/secondary_view_content.dart';

void main() {
  for (final SampleViewKind kind in SampleViewKind.values) {
    testWidgets('renders secondary content for ${kind.label}', (
      WidgetTester tester,
    ) async {
      final SampleViewSpec spec = SampleViewSpec(
        localId: 'test-${kind.name}',
        title: kind.label,
        kind: kind,
        geometry: const Rect.fromLTWH(0, 0, 320, 220),
        transparent: kind.defaultTransparent,
        userPixelRatio: kind.defaultPixelRatio,
        generation: 1,
        viewId: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 220,
            child: SecondaryViewContent(spec: spec),
          ),
        ),
      );

      expect(find.text(kind.label), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
