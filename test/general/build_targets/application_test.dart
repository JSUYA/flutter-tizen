// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/application.dart';
import 'package:flutter_tizen/tizen_build_info.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/package_config.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Logger logger;
  late Artifacts artifacts;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
    logger = BufferLogger.test();
    artifacts = Artifacts.test();
  });

  testUsingContext('Debug bundle contains expected resources', () async {
    final environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{kBuildMode: 'debug'},
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
    environment.buildDir.childFile('app.dill').createSync(recursive: true);
    fileSystem
        .file(artifacts.getArtifactPath(Artifact.vmSnapshotData, mode: BuildMode.debug))
        .createSync(recursive: true);
    fileSystem
        .file(artifacts.getArtifactPath(Artifact.isolateSnapshotData, mode: BuildMode.debug))
        .createSync(recursive: true);

    await DebugTizenApplication(const TizenBuildInfo(
      BuildInfo.debug,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory bundleDir = environment.buildDir.childDirectory('flutter_assets');
    expect(bundleDir.childFile('vm_snapshot_data'), exists);
    expect(bundleDir.childFile('isolate_snapshot_data'), exists);
    expect(bundleDir.childFile('kernel_blob.bin'), exists);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });

  testUsingContext('Bundle filters assets with Tizen asset platform', () async {
    fileSystem.file('pubspec.yaml')
      ..createSync()
      ..writeAsStringSync('''
name: example
flutter:
  assets:
    - path: assets/common.txt
    - path: assets/tizen.txt
      platforms:
        - tizen
    - path: assets/android.txt
      platforms:
        - android
''');
    writePackageConfigFiles(
      directory: fileSystem.currentDirectory,
      mainLibName: 'example',
    );
    fileSystem.file('assets/common.txt').createSync(recursive: true);
    fileSystem.file('assets/tizen.txt').createSync(recursive: true);
    fileSystem.file('assets/android.txt').createSync(recursive: true);

    final environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{kBuildMode: 'release'},
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );

    await ReleaseTizenApplication(const TizenBuildInfo(
      BuildInfo.release,
      targetArch: 'arm',
      deviceProfile: 'common',
    )).build(environment);

    final Directory bundleDir = environment.buildDir.childDirectory('flutter_assets');
    expect(bundleDir.childFile('assets/common.txt'), exists);
    expect(bundleDir.childFile('assets/tizen.txt'), exists);
    expect(bundleDir.childFile('assets/android.txt'), isNot(exists));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });
}
