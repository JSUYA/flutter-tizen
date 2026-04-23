// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tizen/flutter_tizen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tizen/multi_view');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'addView':
          return 1;
        case 'removeView':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('addView returns assigned id', () async {
    final TizenViewHandle handle = await TizenMultiView.addView(
      width: 400,
      height: 300,
    );

    expect(handle.viewId, 1);
    expect(calls.single.method, 'addView');
  });

  test('removeView returns bool', () async {
    expect(await TizenMultiView.removeView(1), isTrue);
    expect(calls.single.method, 'removeView');
  });

  test('addView rejects invalid geometry', () async {
    await expectLater(
      TizenMultiView.addView(width: -1, height: 300),
      throwsArgumentError,
    );
    await expectLater(
      TizenMultiView.addView(width: 400, height: -1),
      throwsArgumentError,
    );
    await expectLater(
      TizenMultiView.addView(userPixelRatio: -1.0),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });

  test('removeView rejects implicit view', () async {
    await expectLater(TizenMultiView.removeView(0), throwsArgumentError);
    expect(calls, isEmpty);
  });
}
