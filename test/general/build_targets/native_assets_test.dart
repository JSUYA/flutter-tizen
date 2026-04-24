// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:code_assets/code_assets.dart';
import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tizen/build_targets/native_assets.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/isolated/native_assets/native_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:hooks_runner/hooks_runner.dart' as native;

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/package_config.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;
  late Logger logger;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.any();
    logger = BufferLogger.test();
  });

  const cases = <String, Architecture>{
    'android-arm': Architecture.arm,
    'android-arm64': Architecture.arm64,
    'android-x64': Architecture.x64,
    'flutter-tester': Architecture.ia32,
  };

  for (final MapEntry<String, Architecture> entry in cases.entries) {
    testUsingContext('Tizen hooks use Linux OS for ${entry.key}', () async {
      final Directory projectDir = fileSystem.currentDirectory;
      writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
      final environment = Environment.test(
        projectDir,
        defines: <String, String>{
          kBuildMode: 'debug',
          kTargetPlatform: entry.key,
        },
        fileSystem: fileSystem,
        logger: logger,
        artifacts: Artifacts.test(),
        processManager: processManager,
      );
      final runner = _RecordingRunner();

      await TizenDartBuild(buildRunner: runner).build(environment);

      final CodeAssetExtension codeExtension =
          runner.extensions!.whereType<CodeAssetExtension>().single;
      expect(codeExtension.targetOS, OS.linux);
      expect(codeExtension.targetArchitecture, entry.value);
      expect(codeExtension.android, isNull);
      expect(runner.setCCompilerConfigCalls, 0);
    }, overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
    });
  }

  testUsingContext('TizenInstallCodeAssets installs Linux layout for Android aliases', () async {
    final Directory projectDir = fileSystem.currentDirectory;
    writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
    final environment = Environment.test(
      projectDir,
      defines: <String, String>{
        kBuildMode: 'debug',
        kTargetPlatform: 'android-arm64',
      },
      fileSystem: fileSystem,
      logger: logger,
      artifacts: Artifacts.test(),
      processManager: processManager,
    );
    final File libFile = fileSystem.file('/tmp/libfoo.so')..createSync(recursive: true);
    final codeAsset = CodeAsset(
      package: 'foo',
      name: 'foo.dart',
      linkMode: DynamicLoadingBundled(),
      file: libFile.uri,
    );
    final resultJson = <String, Object?>{
      'build_start': DateTime.now().toIso8601String(),
      'build_end': DateTime.now().toIso8601String(),
      'dependencies': const <String>[],
      'code_assets': <Object>[
        <String, Object>{
          'asset': codeAsset.encode().toJson(),
          'target': native.Target.fromArchitectureAndOS(Architecture.arm64, OS.linux).toString(),
        },
      ],
      'data_assets': const <Object>[],
    };
    environment.buildDir.createSync(recursive: true);
    environment.buildDir
        .childFile(TizenDartBuild.dartHookResultFilename)
        .writeAsStringSync(json.encode(resultJson));

    await const TizenInstallCodeAssets().build(environment);

    expect(
        projectDir
            .childDirectory('build')
            .childDirectory('native_assets')
            .childDirectory('linux')
            .childFile('libfoo.so'),
        exists);
    expect(
        projectDir
            .childDirectory('build')
            .childDirectory('native_assets')
            .childDirectory('android'),
        isNot(exists));
    final decoded =
        json.decode(environment.buildDir.childFile('native_assets.json').readAsStringSync())
            as Map<String, Object?>;
    final nativeAssets = decoded['native-assets']! as Map<String, Object?>;
    expect(nativeAssets.keys.single, 'linux_arm64');
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });
}

class _RecordingRunner implements FlutterNativeAssetsBuildRunner {
  List<ProtocolExtension>? extensions;
  int setCCompilerConfigCalls = 0;

  @override
  Future<List<String>> packagesWithNativeAssets() async => <String>['native_package'];

  @override
  Future<native.BuildResult?> build({
    required List<ProtocolExtension> extensions,
    required bool linkingEnabled,
  }) async {
    this.extensions = extensions;
    return const _EmptyBuildResult();
  }

  @override
  Future<native.LinkResult?> link({
    required List<ProtocolExtension> extensions,
    required native.BuildResult buildResult,
  }) async {
    throw StateError('Link hooks should not run for debug builds.');
  }

  @override
  Future<void> setCCompilerConfig(Object target) async {
    setCCompilerConfigCalls++;
  }
}

class _EmptyBuildResult implements native.BuildResult {
  const _EmptyBuildResult();

  @override
  List<EncodedAsset> get encodedAssets => const <EncodedAsset>[];

  @override
  Map<String, List<EncodedAsset>> get encodedAssetsForLinking =>
      const <String, List<EncodedAsset>>{};

  @override
  List<Uri> get dependencies => const <Uri>[];
}
