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
  late Artifacts artifacts;

  Environment makeEnvironment({
    required String targetPlatform,
    required String buildMode,
  }) {
    final Directory projectDir = fileSystem.currentDirectory;
    writePackageConfigFiles(directory: projectDir, mainLibName: 'my_app');
    projectDir.childDirectory('tizen').childFile('tizen-manifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
<manifest package="package_id" version="1.0.0" api-version="8.0">
  <profile name="common"/>
  <ui-application appid="app_id" exec="Runner.dll" type="dotnet"/>
</manifest>
''');
    return Environment.test(
      projectDir,
      defines: <String, String>{
        kBuildMode: buildMode,
        kTargetPlatform: targetPlatform,
      },
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
    );
  }

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.any();
    logger = BufferLogger.test();
    artifacts = Artifacts.test();
  });

  const cases = <String, Architecture>{
    'android-arm': Architecture.arm,
    'android-arm64': Architecture.arm64,
    'android-x64': Architecture.x64,
    'flutter-tester': Architecture.ia32,
  };

  for (final MapEntry<String, Architecture> entry in cases.entries) {
    testUsingContext('Tizen hooks use Linux OS for ${entry.key}', () async {
      final runner = _RecordingRunner();

      await TizenDartBuild(buildRunner: runner)
          .build(makeEnvironment(targetPlatform: entry.key, buildMode: 'debug'));

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

  testUsingContext(
    'TizenInstallCodeAssets writes linux key and installed lib path',
    () async {
      final Environment environment =
          makeEnvironment(targetPlatform: 'android-arm64', buildMode: 'debug');
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
        fileSystem.currentDirectory
            .childDirectory('build')
            .childDirectory('native_assets')
            .childDirectory('linux')
            .childFile('libfoo.so'),
        exists,
      );
      final File manifest = environment.buildDir.childFile('native_assets.json');
      expect(manifest, exists);
      final decoded = json.decode(manifest.readAsStringSync()) as Map<String, Object?>;
      final nativeAssets = decoded['native-assets']! as Map<String, Object?>;
      expect(nativeAssets.keys.single, 'linux_arm64');

      final entries = nativeAssets['linux_arm64']! as Map<String, Object?>;
      final pathParts = entries['package:foo/foo.dart']! as List<Object?>;
      expect(pathParts, <Object?>[
        'absolute',
        '/opt/usr/globalapps/package_id/lib/libfoo.so',
      ]);
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      ProcessManager: () => processManager,
    },
  );
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
