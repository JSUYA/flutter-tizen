// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/flutter_application_package.dart';
import 'package:flutter_tools/src/project.dart';

import 'tizen_tpk.dart';

/// [FlutterApplicationPackageFactory] extended for Tizen.
class TizenApplicationPackageFactory extends FlutterApplicationPackageFactory {
  TizenApplicationPackageFactory({
    required super.androidSdk,
    required super.processManager,
    required super.logger,
    required super.userMessages,
    required super.fileSystem,
  });

  @override
  Future<ApplicationPackage?> getPackageForPlatform(
    TargetPlatform platform, {
    BuildInfo? buildInfo,
    File? applicationBinary,
  }) async {
    if (_isTizenPlatform(platform, applicationBinary)) {
      return applicationBinary == null
          ? TizenTpk.fromProject(FlutterProject.current())
          : TizenTpk.fromTpk(applicationBinary);
    }
    return super.getPackageForPlatform(platform,
        buildInfo: buildInfo, applicationBinary: applicationBinary);
  }

  /// Tizen devices report the Android platforms as architecture aliases, so an
  /// Android platform means a Tizen package when the app is a TPK or the
  /// project has a Tizen directory.
  bool _isTizenPlatform(TargetPlatform platform, File? applicationBinary) {
    return switch (platform) {
      TargetPlatform.tester => true,
      TargetPlatform.android_arm ||
      TargetPlatform.android_arm64 ||
      TargetPlatform.android_x64 =>
        applicationBinary?.path.endsWith('.tpk') ??
            FlutterProject.current().directory.childDirectory('tizen').existsSync(),
      _ => false,
    };
  }
}
