// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:support_ffi_plugin_sample/support_ffi_plugin_sample.dart';

void main() {
  test('calls libc through dart:ffi', () {
    expect(SupportFfiPluginSample.registrationStyle, 'ffiPlugin');
    expect(SupportFfiPluginSample.processId, greaterThan(0));
  });
}
