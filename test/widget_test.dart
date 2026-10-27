import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:torch_tool/main.dart';

void main() {
  testWidgets('torch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TorchToolApp());

    expect(find.text('Torch Tool'), findsOneWidget);
    expect(find.byKey(const Key('torch-lens')), findsOneWidget);
    expect(find.text('Torch is off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('power-button')));
    await tester.pump();
    expect(find.textContaining('Steady beam'), findsOneWidget);
  });
}
