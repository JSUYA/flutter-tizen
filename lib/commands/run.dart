// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/commands/run.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/target_devices.dart';

import '../tizen_build_info.dart';
import '../tizen_cache.dart';
import '../tizen_device.dart';
import '../tizen_plugins.dart';

class TizenRunCommand extends RunCommand with DartPluginRegistry, TizenRequiredArtifacts {
  TizenRunCommand({super.verboseHelp});

  @override
  Future<List<Device>?> findAllTargetDevices({
    bool? canPrompt,
    bool includeDevicesUnsupportedByProject = false,
  }) async {
    final List<Device> devices = await globals.deviceManager!.getDevices();
    final tizenDeviceLogger = TizenDeviceLogger(
      logger: globals.logger,
      devices: devices,
    );
    return TargetDevices(
      deviceManager: globals.deviceManager!,
      logger: tizenDeviceLogger,
      deviceConnectionInterface: deviceConnectionInterface,
      platform: globals.platform,
    ).findAllTargetDevices(
      canPrompt: canPrompt ?? !outputMachineFormat,
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      includeDevicesUnsupportedByProject: includeDevicesUnsupportedByProject,
    );
  }
}

/// A [Logger] that fixes the device information for Tizen devices.
class TizenDeviceLogger extends DelegatingLogger {
  TizenDeviceLogger({
    required Logger logger,
    required List<Device> devices,
  })  : _devices = devices.whereType<TizenDevice>().toList(growable: false),
        super(logger);

  final List<TizenDevice> _devices;

  @override
  void printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    for (final TizenDevice device in _devices) {
      if (message.contains(device.name) && message.contains('Tizen')) {
        final String platformName = getTargetPlatformForArch(device.architecture).getName();
        message = message
            .replaceFirst(
              '(${Category.mobile})',
              '(${device.deviceProfile})${device.deviceProfile == 'tv' ? '    ' : ''}',
            )
            .replaceFirst(
              platformName,
              'tizen-${device.architecture}'.padRight(platformName.length),
            );
      }
    }

    super.printStatus(
      message,
      emphasis: emphasis,
      color: color,
      newline: newline,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
    );
  }
}
