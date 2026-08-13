// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/version.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

extension PathUtils on String {
  /// On non-Windows, encloses the string with [encloseWith].
  ///
  /// On Windows, converts Windows-style path (e.g. 'C:\x\y') into POSIX path
  /// ('/c/x/y') and encloses with [encloseWith].
  String toPosixPath([String encloseWith = '"']) {
    var path = this;
    if (globals.platform.isWindows) {
      path = path.replaceAll(r'\', '/');
      if (path.startsWith(':', 1)) {
        path = '/${path[0].toLowerCase()}${path.substring(2)}';
      }
    }
    return encloseWith + path + encloseWith;
  }
}

String getBuildConfig(BuildMode buildMode) {
  return buildMode == BuildMode.debug ? 'Debug' : 'Release';
}

Directory getEngineArtifactsDirectory(String arch, BuildMode mode) {
  if (arch == 'x86_64') {
    arch = 'x64';
  }
  return globals.artifacts!.usesLocalArtifacts
      ? globals.fs.directory(globals.artifacts!.localEngineInfo!.targetOutPath)
      : globals.cache.getArtifactDirectory('engine').childDirectory('tizen-$arch-${mode.name}');
}

Directory getEmbedderArtifactsDirectory(String? apiVersion, String arch) {
  final Version version = Version.parse(apiVersion) ?? Version(6, 0, 0);
  if (arch == 'x86_64') {
    arch = 'x64';
  }

  if (arch == 'x64' && version >= Version(8, 0, 0)) {
    apiVersion = '8.0';
  } else if (version >= Version(6, 5, 0)) {
    apiVersion = '6.5';
  } else {
    apiVersion = '6.0';
  }
  return globals.cache
      .getArtifactDirectory('engine')
      .childDirectory('tizen-$arch')
      .childDirectory(apiVersion);
}

Directory getCommonArtifactsDirectory() {
  return globals.cache.getArtifactDirectory('engine').childDirectory('tizen-common');
}

Directory getDartSdkDirectory() {
  return globals.cache.getCacheDir('dart-sdk');
}

/// Removes the "lib" prefix and file extension from [name] and returns.
String getLibNameForFileName(String name) {
  if (name.startsWith('lib')) {
    name = name.substring(3);
  }
  if (name.lastIndexOf('.') > 0) {
    name = name.substring(0, name.lastIndexOf('.'));
  }
  return name;
}

/// Recompresses the TPK [input] with the maximum deflate compression level
/// and writes the result to [output].
///
/// The Tizen CLI creates TPK archives with the default compression level.
/// Recompressing at the maximum level typically reduces the package size by
/// a few percent at a small build time cost. Only the zip container is
/// rewritten and the archived file contents are left unchanged, so the
/// package signatures remain valid.
///
/// If [input] cannot be read as a zip archive, it is copied to [output]
/// unchanged.
void repackTpk(File input, File output) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(input.readAsBytesSync());
  } on FormatException {
    input.copySync(output.path);
    return;
  }
  final repacked = Archive();
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    final copy = ArchiveFile(file.name, file.size, file.content as List<int>)
      ..mode = file.mode
      ..lastModTime = file.lastModTime;
    repacked.addFile(copy);
  }
  output.writeAsBytesSync(
      ZipEncoder().encode(repacked, level: Deflate.BEST_COMPRESSION)!);
}
