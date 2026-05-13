// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:support_ffi_plugin_sample/support_ffi_plugin_sample.dart';

void main() => runApp(const SampleApp());

/// Sample app that depends on an FFI-only Tizen plugin.
class SampleApp extends StatelessWidget {
  /// Creates the sample app.
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FFI-only Tizen plugin sample'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('registration: ${SupportFfiPluginSample.registrationStyle}'),
              Text('pointer size: ${SupportFfiPluginSample.pointerSize} bytes'),
            ],
          ),
        ),
      ),
    );
  }
}
