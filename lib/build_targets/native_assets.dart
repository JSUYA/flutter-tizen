// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:code_assets/code_assets.dart';
import 'package:data_assets/data_assets.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/depfile.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';
import 'package:flutter_tools/src/build_system/targets/native_assets.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/dart/package_map.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/isolated/native_assets/dart_hook_result.dart';
import 'package:flutter_tools/src/isolated/native_assets/native_assets.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:hooks/hooks.dart';
import 'package:hooks_runner/hooks_runner.dart' as native;
import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';

import '../tizen_project.dart';
import '../tizen_tpk.dart';

/// Source: [DartBuild] in `native_assets.dart`
class TizenDartBuild extends Target {
  const TizenDartBuild({
    @visibleForTesting FlutterNativeAssetsBuildRunner? buildRunner,
    this.specifiedTargetPlatform,
  }) : _buildRunner = buildRunner;

  final FlutterNativeAssetsBuildRunner? _buildRunner;

  /// The target OS and architecture that we are building for.
  final TargetPlatform? specifiedTargetPlatform;

  @override
  Future<void> build(Environment environment) async {
    final FileSystem fileSystem = environment.fileSystem;
    final TargetPlatform targetPlatform =
        specifiedTargetPlatform ?? _getTargetPlatformFromEnvironment(environment, name);

    final File packageConfigFile = fileSystem.file(environment.packageConfigPath);
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      packageConfigFile,
      logger: environment.logger,
    );
    final Uri projectUri = environment.projectDir.uri;
    final String? runPackageName =
        packageConfig.packages.where((Package p) => p.root == projectUri).firstOrNull?.name;
    if (runPackageName == null) {
      throw StateError(
        'Could not determine run package name. '
        'Project path "${projectUri.toFilePath()}" did not occur as package '
        'root in package config "${environment.packageConfigPath}". '
        'Please report a reproduction on '
        'https://github.com/flutter/flutter/issues/169475.',
      );
    }
    final String pubspecPath = packageConfigFile.uri.resolve('../pubspec.yaml').toFilePath();
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final buildMode = BuildMode.fromCliName(buildModeEnvironment);
    final bool includeDevDependencies = !buildMode.isRelease;
    final FlutterNativeAssetsBuildRunner buildRunner = _buildRunner ??
        FlutterNativeAssetsBuildRunnerImpl(
          environment.packageConfigPath,
          packageConfig,
          fileSystem,
          environment.logger,
          runPackageName,
          includeDevDependencies: includeDevDependencies,
          pubspecPath,
        );
    final DartHooksResult result = await _runTizenSpecificHooks(
      buildRunner: buildRunner,
      targetPlatform: targetPlatform,
      projectUri: projectUri,
      fileSystem: fileSystem,
      buildMode: buildMode,
    );
    final File dartHookResultJsonFile = environment.buildDir.childFile(dartHookResultFilename);
    if (!dartHookResultJsonFile.parent.existsSync()) {
      dartHookResultJsonFile.parent.createSync(recursive: true);
    }
    dartHookResultJsonFile.writeAsStringSync(json.encode(result.toJson()));

    final depfile = Depfile(
      <File>[for (final Uri dependency in result.dependencies) fileSystem.file(dependency)],
      <File>[fileSystem.file(dartHookResultJsonFile)],
    );
    final File outputDepfile = environment.buildDir.childFile(depFilename);
    if (!outputDepfile.parent.existsSync()) {
      outputDepfile.parent.createSync(recursive: true);
    }
    environment.depFileService.writeToFile(depfile, outputDepfile);
    if (!await outputDepfile.exists()) {
      throw StateError("${outputDepfile.path} doesn't exist.");
    }
  }

  @override
  List<String> get depfiles => const <String>[depFilename];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern(
          '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/native_assets.dart',
        ),
        // If different packages are resolved, different native assets might need to be built.
        Source.pattern('{WORKSPACE_DIR}/.dart_tool/package_config.json'),
        // TODO(mosuem): Should consume resources.json. https://github.com/flutter/flutter/issues/146263
      ];

  @override
  String get name => 'dart_build';

  @override
  List<Source> get outputs => const <Source>[Source.pattern('{BUILD_DIR}/$dartHookResultFilename')];

  /// Dependent build [Target]s can use this to consume the result of the
  /// [TizenDartBuild] target.
  static Future<DartHooksResult> loadHookResult(Environment environment) async {
    final File dartHookResultJsonFile = environment.buildDir.childFile(
      TizenDartBuild.dartHookResultFilename,
    );
    if (!dartHookResultJsonFile.existsSync()) {
      return DartHooksResult.empty();
    }
    return DartHooksResult.fromJson(
      json.decode(dartHookResultJsonFile.readAsStringSync()) as Map<String, Object?>,
    );
  }

  @override
  List<Target> get dependencies => <Target>[];

  static const dartHookResultFilename = 'dart_build_result.json';
  static const depFilename = 'dart_build.d';
}

/// Source: [DartBuildForNative] in `native_assets.dart`
class TizenDartBuildForNative extends TizenDartBuild {
  const TizenDartBuildForNative({@visibleForTesting super.buildRunner});

  // TODO(dcharkes): Add `KernelSnapshot()` for AOT builds only when adding tree-shaking information. https://github.com/dart-lang/native/issues/153
  @override
  List<Target> get dependencies => const <Target>[];
}

/// Installs bundled code assets produced by [TizenDartBuild] into a Linux-style
/// flat layout under `build/native_assets/linux/` and writes the
/// `native_assets.json` manifest consumed by the engine at runtime.
///
/// Upstream's `InstallCodeAssets` dispatches through
/// `getNativeOSFromTargetPlatform`, which would return `OS.android` for Tizen's
/// Android-aliased target platforms, producing a JNI directory layout. Tizen
/// needs a flat `.so` layout to match the TPK's `lib/` directory, so this
/// target re-implements the install logic against `OS.linux` while reusing
/// upstream's [assetTargetLocationsForOS] for the kernel asset mapping.
///
/// Source: `InstallCodeAssets` in upstream `build_system/targets/native_assets.dart`.
class TizenInstallCodeAssets extends Target {
  const TizenInstallCodeAssets();

  @override
  Future<void> build(Environment environment) async {
    final Uri projectUri = environment.projectDir.uri;
    final FileSystem fileSystem = environment.fileSystem;

    final DartHooksResult dartHookResult = await TizenDartBuild.loadHookResult(environment);
    final Uri nativeAssetsFileUri = environment.buildDir.childFile(nativeAssetsFilename).uri;
    final Uri buildUri = nativeAssetsBuildUri(projectUri, OS.linux.name);

    // Reuse upstream's public helper to map code assets to their final kernel
    // locations (flat layout for OS.linux).
    final Map<FlutterCodeAsset, native.KernelAsset> assetTargetLocations =
        assetTargetLocationsForOS(
      OS.linux,
      dartHookResult.codeAssets,
      /* flutterTester= */ false,
      buildUri,
    );
    _pruneStaleBundledCodeAssets(
      buildUri: buildUri,
      assetTargetLocations: assetTargetLocations,
      fileSystem: fileSystem,
    );

    await _copyBundledCodeAssets(
      buildUri: buildUri,
      assetTargetLocations: assetTargetLocations,
      fileSystem: fileSystem,
    );
    await _writeTizenNativeAssetsJson(
      assetTargetLocations.values.toList(),
      nativeAssetsFileUri,
      fileSystem,
      packageId: dartHookResult.codeAssets.isEmpty ? null : _tizenPackageId(environment),
    );

    final depfile = Depfile(
      <File>[for (final Uri file in dartHookResult.filesToBeBundled) fileSystem.file(file)],
      <File>[fileSystem.file(nativeAssetsFileUri)],
    );
    environment.depFileService.writeToFile(
      depfile,
      environment.buildDir.childFile(depFilename),
    );
  }

  @override
  List<String> get depfiles => <String>[depFilename];

  @override
  List<Target> get dependencies => const <Target>[TizenDartBuildForNative()];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern(
          '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/native_assets.dart',
        ),
        Source.pattern('{FLUTTER_ROOT}/../lib/build_targets/native_assets.dart'),
        Source.pattern('{PROJECT_DIR}/tizen/tizen-manifest.xml'),
        Source.pattern('{PROJECT_DIR}/tizen/ui/tizen-manifest.xml'),
        Source.pattern('{PROJECT_DIR}/.tizen/tizen-manifest.xml'),
        Source.pattern('{WORKSPACE_DIR}/.dart_tool/package_config.json'),
      ];

  @override
  String get name => 'install_code_assets';

  @override
  List<Source> get outputs => const <Source>[Source.pattern('{BUILD_DIR}/$nativeAssetsFilename')];

  static const nativeAssetsFilename = 'native_assets.json';
  static const depFilename = 'install_code_assets.d';
}

TargetPlatform _getTargetPlatformFromEnvironment(Environment environment, String name) {
  final String? targetPlatformEnvironment = environment.defines[kTargetPlatform];
  if (targetPlatformEnvironment == null) {
    throw MissingDefineException(kTargetPlatform, name);
  }
  return getTargetPlatformForName(targetPlatformEnvironment);
}

Future<DartHooksResult> _runTizenSpecificHooks({
  required FlutterNativeAssetsBuildRunner buildRunner,
  required TargetPlatform targetPlatform,
  required Uri projectUri,
  required FileSystem fileSystem,
  required BuildMode buildMode,
}) async {
  final Directory buildDir = fileSystem.directory(nativeAssetsBuildUri(projectUri, OS.linux.name));
  if (!buildDir.existsSync()) {
    buildDir.createSync(recursive: true);
  }

  final List<String> packagesWithNativeAssets = await buildRunner.packagesWithNativeAssets();
  if (packagesWithNativeAssets.isEmpty) {
    return DartHooksResult.empty();
  }
  if (!featureFlags.isNativeAssetsEnabled && !featureFlags.isDartDataAssetsEnabled) {
    throwToolExit(
      'Package(s) ${packagesWithNativeAssets.join(' ')} require the dart assets feature to be enabled.\n'
      '  Enable code assets using `flutter-tizen config --enable-native-assets`.\n'
      '  Enable data assets using `flutter-tizen config --enable-dart-data-assets`.',
    );
  }

  final Architecture architecture = _getTizenNativeArchitecture(targetPlatform);
  // Do not call setCCompilerConfig here. Flutter's Linux compiler discovery
  // would return a host compiler, not a Tizen rootstrap-aware compiler.
  final extensions = <ProtocolExtension>[
    if (featureFlags.isNativeAssetsEnabled)
      CodeAssetExtension(
        targetArchitecture: architecture,
        linkModePreference: LinkModePreference.dynamic,
        targetOS: OS.linux,
      ),
    if (featureFlags.isDartDataAssetsEnabled) DataAssetsExtension(),
  ];
  final linkingEnabled = buildMode != BuildMode.debug;
  final buildStart = DateTime.now();

  final native.BuildResult? buildResult =
      await buildRunner.build(extensions: extensions, linkingEnabled: linkingEnabled);
  if (buildResult == null) {
    throwToolExit('Building native assets failed. See the logs for more details.');
  }

  native.LinkResult? linkResult;
  if (linkingEnabled) {
    linkResult = await buildRunner.link(extensions: extensions, buildResult: buildResult);
    if (linkResult == null) {
      throwToolExit('Linking native assets failed. See the logs for more details.');
    }
  }

  final target = native.Target.fromArchitectureAndOS(architecture, OS.linux);
  final encodedAssets = <EncodedAsset>[
    ...buildResult.encodedAssets,
    if (linkResult != null) ...linkResult.encodedAssets,
  ];
  final codeAssets = <FlutterCodeAsset>[
    for (final EncodedAsset asset in encodedAssets)
      if (asset.isCodeAsset) FlutterCodeAsset(codeAsset: asset.asCodeAsset, target: target),
  ];
  final dataAssets = <DataAsset>[
    for (final EncodedAsset asset in encodedAssets)
      if (asset.isDataAsset) DataAsset.fromEncoded(asset),
  ];
  if (dataAssets.map((DataAsset asset) => asset.id).toSet().length != dataAssets.length) {
    throwToolExit(
      'Found duplicates in the data assets: '
      '${dataAssets.map((DataAsset asset) => asset.id).toList()} '
      'while compiling for linux_${architecture.name}.',
    );
  }
  if (codeAssets.toSet().length != codeAssets.length) {
    throwToolExit(
      'Found duplicates in the code assets: '
      '${codeAssets.map((FlutterCodeAsset asset) => asset.codeAsset.id).toList()} '
      'while compiling for linux_${architecture.name}.',
    );
  }

  return DartHooksResult(
    buildStart: buildStart,
    buildEnd: DateTime.now(),
    codeAssets: codeAssets,
    dataAssets: dataAssets,
    dependencies: <Uri>{
      ...buildResult.dependencies,
      if (linkResult != null) ...linkResult.dependencies,
    }.toList(),
  );
}

typedef _TizenNativeAssetTarget = ({
  Architecture architecture,
  TargetPlatform installTargetPlatform,
});

/// Resolves Flutter target aliases used by Tizen native assets.
///
/// Tizen reuses Flutter's Android/tester target platforms as architecture
/// aliases. Dart hooks must see Linux as the OS, and [installCodeAssets] only
/// needs a Linux [TargetPlatform] to select the copy layout. The actual
/// per-asset architecture is carried by each [FlutterCodeAsset].
_TizenNativeAssetTarget _getTizenNativeAssetTarget(TargetPlatform targetPlatform) {
  return switch (targetPlatform) {
    TargetPlatform.android_arm => (
        architecture: Architecture.arm,
        installTargetPlatform: TargetPlatform.linux_x64,
      ),
    TargetPlatform.android_arm64 => (
        architecture: Architecture.arm64,
        installTargetPlatform: TargetPlatform.linux_arm64,
      ),
    TargetPlatform.android_x64 => (
        architecture: Architecture.x64,
        installTargetPlatform: TargetPlatform.linux_x64,
      ),
    TargetPlatform.tester => (
        architecture: Architecture.ia32,
        installTargetPlatform: TargetPlatform.linux_x64,
      ),
    _ => throwToolExit('Native assets are not supported for $targetPlatform on Tizen.'),
  };
}

Architecture _getTizenNativeArchitecture(TargetPlatform targetPlatform) {
  return _getTizenNativeAssetTarget(targetPlatform).architecture;
}

void _pruneStaleBundledCodeAssets({
  required Uri buildUri,
  required Map<FlutterCodeAsset, native.KernelAsset> assetTargetLocations,
  required FileSystem fileSystem,
}) {
  final Directory buildDir = fileSystem.directory(buildUri);
  if (!buildDir.existsSync()) {
    buildDir.createSync(recursive: true);
    return;
  }
  final currentFiles = <String>{
    for (final MapEntry<FlutterCodeAsset, native.KernelAsset> entry in assetTargetLocations.entries)
      if (entry.key.codeAsset.linkMode is DynamicLoadingBundled)
        (entry.value.path as native.KernelAssetAbsolutePath).uri.pathSegments.last,
  };
  for (final FileSystemEntity entity in buildDir.listSync()) {
    if (currentFiles.contains(entity.basename)) {
      continue;
    }
    entity.deleteSync(recursive: true);
  }
}

String _tizenPackageId(Environment environment) {
  final FlutterProject project = FlutterProject.fromDirectory(environment.projectDir);
  final tizenProject = TizenProject.fromFlutter(project);
  return TizenManifest.parseFromXml(tizenProject.manifestFile).packageId;
}

/// Copies bundled (`DynamicLoadingBundled`) assets from the hook output
/// location to [buildUri] (typically `build/native_assets/linux/`), using the
/// flat filename layout that upstream's [assetTargetLocationsForOS] computes
/// for [OS.linux]. Later consumed by `NativeTpk`/`DotnetTpk` packaging.
///
/// Mirrors upstream's private `_copyNativeCodeAssetsToBundleOnWindowsLinux`
/// helper; kept local because it is not exported.
Future<void> _copyBundledCodeAssets({
  required Uri buildUri,
  required Map<FlutterCodeAsset, native.KernelAsset> assetTargetLocations,
  required FileSystem fileSystem,
}) async {
  for (final MapEntry<FlutterCodeAsset, native.KernelAsset> entry in assetTargetLocations.entries) {
    if (entry.key.codeAsset.linkMode is! DynamicLoadingBundled) {
      continue;
    }
    final Uri source = entry.key.codeAsset.file!;
    final Uri target = (entry.value.path as native.KernelAssetAbsolutePath).uri;
    final Uri targetUri = buildUri.resolveUri(target);
    final File sourceFile = fileSystem.file(source);
    final File targetFile = fileSystem.file(targetUri);
    if (!targetFile.parent.existsSync()) {
      targetFile.parent.createSync(recursive: true);
    }
    if (sourceFile.path == targetFile.path) {
      continue;
    }
    await sourceFile.copy(targetFile.path);
  }
}

/// Writes the `native_assets.json` manifest that the Flutter engine reads at
/// runtime to resolve `@Native`-annotated Dart FFI calls.
///
/// See `assets/native_assets.cc` in the engine for the expected format.
/// Mirrors upstream's private `_writeNativeAssetsJson` / `_toNativeAssetsJsonFile`;
/// kept local because those helpers are not exported.
Future<void> _writeTizenNativeAssetsJson(
  List<native.KernelAsset> assets,
  Uri nativeAssetsJsonUri,
  FileSystem fileSystem, {
  required String? packageId,
}) async {
  final assetsPerTarget = <native.Target, List<native.KernelAsset>>{};
  for (final asset in assets) {
    assetsPerTarget.putIfAbsent(asset.target, () => <native.KernelAsset>[]).add(asset);
  }
  final jsonContents = <String, Object>{
    'format-version': const <int>[1, 0, 0],
    'native-assets': <String, Map<String, List<String>>>{
      for (final MapEntry<native.Target, List<native.KernelAsset>> entry in assetsPerTarget.entries)
        entry.key.toString(): <String, List<String>>{
          for (final native.KernelAsset e in entry.value)
            e.id: _tizenRuntimeAssetPath(e.path, packageId).toJson(),
        },
    },
  };
  final File nativeAssetsFile = fileSystem.file(nativeAssetsJsonUri);
  nativeAssetsFile.parent.createSync(recursive: true);
  await nativeAssetsFile.writeAsString(jsonEncode(jsonContents));
}

native.KernelAssetPath _tizenRuntimeAssetPath(native.KernelAssetPath path, String? packageId) {
  if (packageId == null) {
    return path;
  }
  if (path is native.KernelAssetAbsolutePath) {
    final Uri uri = path.uri;
    if (uri.scheme.isEmpty && !uri.path.startsWith('/')) {
      final String fileName = uri.pathSegments.last;
      return native.KernelAssetAbsolutePath(
        Uri.file('/opt/usr/globalapps/$packageId/lib/$fileName'),
      );
    }
  }
  return path;
}

/// Resolves the directory where [TizenInstallCodeAssets] places bundled `.so`
/// files for a project. Used by packaging targets to ship the files inside the
/// TPK's `lib/` directory.
Directory nativeAssetsLibraryDirectory(Directory projectDir) =>
    projectDir.fileSystem.directory(nativeAssetsBuildUri(projectDir.uri, OS.linux.name));
