// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:code_assets/code_assets.dart';
import 'package:file/memory.dart';
import 'package:flutter_tizen/build_targets/native_assets.dart';
import 'package:flutter_tools/src/base/file_system.dart';

import '../../src/common.dart';
import '../../src/context.dart';

void main() {
  late FileSystem fileSystem;
  late FakeProcessManager processManager;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.empty();
  });

  testUsingContext('Falls back to PATH when linker is not next to clang++', () async {
    fileSystem.file('/usr/lib/llvm-18/bin/clang++').createSync(recursive: true);
    fileSystem.file('/usr/lib/llvm-18/bin/clang').createSync(recursive: true);
    fileSystem.file('/usr/lib/llvm-18/bin/llvm-ar').createSync(recursive: true);
    fileSystem.file('/usr/bin/ld').createSync(recursive: true);
    fileSystem.link('/usr/bin/clang++').createSync('/usr/lib/llvm-18/bin/clang++');

    processManager.addCommands(<FakeCommand>[
      const FakeCommand(
        command: <String>['which', 'clang++'],
        stdout: '/usr/bin/clang++\n',
      ),
      const FakeCommand(
        command: <String>['which', 'clang++'],
        stdout: '/usr/bin/clang++\n',
      ),
      const FakeCommand(
        command: <String>['which', 'ld.lld'],
        exitCode: 1,
      ),
      const FakeCommand(
        command: <String>['which', 'ld'],
        stdout: '/usr/bin/ld\n',
      ),
    ]);

    final CCompilerConfig? config = await tizenCCompilerConfigLinux(
      fileSystem: fileSystem,
      processManager: processManager,
      throwIfNotFound: true,
    );

    expect(config, isNotNull);
    expect(config!.compiler.toFilePath(), '/usr/lib/llvm-18/bin/clang');
    expect(config.archiver.toFilePath(), '/usr/lib/llvm-18/bin/llvm-ar');
    expect(config.linker.toFilePath(), '/usr/bin/ld');
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });

  testUsingContext('Reports a clear error when no linker is available', () async {
    fileSystem.file('/usr/lib/llvm-18/bin/clang++').createSync(recursive: true);
    fileSystem.file('/usr/lib/llvm-18/bin/clang').createSync(recursive: true);
    fileSystem.file('/usr/lib/llvm-18/bin/llvm-ar').createSync(recursive: true);
    fileSystem.directory('/usr/bin').createSync(recursive: true);
    fileSystem.link('/usr/bin/clang++').createSync('/usr/lib/llvm-18/bin/clang++');

    processManager.addCommands(<FakeCommand>[
      const FakeCommand(
        command: <String>['which', 'clang++'],
        stdout: '/usr/bin/clang++\n',
      ),
      const FakeCommand(
        command: <String>['which', 'clang++'],
        stdout: '/usr/bin/clang++\n',
      ),
      const FakeCommand(
        command: <String>['which', 'ld.lld'],
        exitCode: 1,
      ),
      const FakeCommand(
        command: <String>['which', 'ld'],
        exitCode: 1,
      ),
    ]);

    await expectLater(
      () => tizenCCompilerConfigLinux(
        fileSystem: fileSystem,
        processManager: processManager,
        throwIfNotFound: true,
      ),
      throwsToolExit(
        message: 'Install the lld or binutils package to provide a linker.',
      ),
    );
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
  });
}
