import 'dart:convert';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../tizen_device.dart';

/// Source: [DevicesCommand] in `devices.dart`
class TizenDevicesCommand extends DevicesCommand {
  TizenDevicesCommand({super.verboseHelp});

  @override
  Future<FlutterCommandResult> runCommand() async {
    if (globals.doctor?.canListAnything != true) {
      throwToolExit(
        "Unable to locate a development device; please run 'flutter doctor' for "
        'information about installing additional components.',
        exitCode: 1,
      );
    }

    final output = TizenDevicesCommandOutput(
      platform: globals.platform,
      logger: globals.logger,
      deviceManager: globals.deviceManager,
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      deviceConnectionInterface: deviceConnectionInterface,
    );

    await output.findAndOutputAllTargetDevices(machine: outputMachineFormat);

    return FlutterCommandResult.success();
  }
}

/// Source: [DevicesCommandOutput] in `devices.dart`
class TizenDevicesCommandOutput {
  factory TizenDevicesCommandOutput({
    // ignore: avoid_unused_constructor_parameters
    required Platform platform,
    required Logger logger,
    DeviceManager? deviceManager,
    Duration? deviceDiscoveryTimeout,
    DeviceConnectionInterface? deviceConnectionInterface,
  }) {
    return TizenDevicesCommandOutput._private(
      logger: logger,
      deviceManager: deviceManager,
      deviceDiscoveryTimeout: deviceDiscoveryTimeout,
      deviceConnectionInterface: deviceConnectionInterface,
    );
  }

  /// Source: [DevicesCommandOutput._private] in `devices.dart`
  TizenDevicesCommandOutput._private({
    required Logger logger,
    required DeviceManager? deviceManager,
    required this.deviceDiscoveryTimeout,
    required this.deviceConnectionInterface,
  })  : _deviceManager = deviceManager,
        _logger = logger;

  final DeviceManager? _deviceManager;
  final Logger _logger;
  final Duration? deviceDiscoveryTimeout;
  final DeviceConnectionInterface? deviceConnectionInterface;

  /// Source: [DevicesCommandOutput._includeAttachedDevices] in `devices.dart`
  bool get _includeAttachedDevices =>
      deviceConnectionInterface == null ||
      deviceConnectionInterface == DeviceConnectionInterface.attached;

  /// Source: [DevicesCommandOutput._includeWirelessDevices] in `devices.dart`
  bool get _includeWirelessDevices =>
      deviceConnectionInterface == null ||
      deviceConnectionInterface == DeviceConnectionInterface.wireless;

  /// Source: [DevicesCommandOutput._getAttachedDevices] in `devices.dart`
  Future<List<Device>> _getAttachedDevices(DeviceManager deviceManager) async {
    if (!_includeAttachedDevices) {
      return <Device>[];
    }
    return deviceManager.getAllDevices(
      filter: DeviceDiscoveryFilter(deviceConnectionInterface: DeviceConnectionInterface.attached),
    );
  }

  /// Source: [DevicesCommandOutput._getWirelessDevices] in `devices.dart`
  Future<List<Device>> _getWirelessDevices(DeviceManager deviceManager) async {
    if (!_includeWirelessDevices) {
      return <Device>[];
    }
    return deviceManager.getAllDevices(
      filter: DeviceDiscoveryFilter(deviceConnectionInterface: DeviceConnectionInterface.wireless),
    );
  }

  /// Source: [DevicesCommandOutput.findAndOutputAllTargetDevices] in `devices.dart`
  Future<void> findAndOutputAllTargetDevices({required bool machine}) async {
    // Match upstream behavior: if the user did not set a timeout and did not
    // filter to attached-only devices, perform longer wireless discovery.
    if (deviceDiscoveryTimeout == null &&
        deviceConnectionInterface != DeviceConnectionInterface.attached) {
      if (machine) {
        final List<Device> devices = await _deviceManager?.refreshAllDevices(
              filter: DeviceDiscoveryFilter(deviceConnectionInterface: deviceConnectionInterface),
              timeout: DeviceManager.minimumWirelessDeviceDiscoveryTimeout,
            ) ??
            <Device>[];
        await printDevicesAsJson(devices);
        return;
      }

      final Future<void>? extendedWirelessDiscovery =
          _deviceManager?.refreshExtendedWirelessDeviceDiscoverers(
        timeout: DeviceManager.minimumWirelessDeviceDiscoveryTimeout,
      );

      var attachedDevices = <Device>[];
      final DeviceManager? deviceManager = _deviceManager;
      if (deviceManager != null) {
        attachedDevices = await _getAttachedDevices(deviceManager);
      }

      // Number of lines to clear starts at 1 because it's inclusive of the line
      // the cursor is on, which will be blank for this use case.
      var numLinesToClear = 1;

      // Display list of attached devices.
      if (attachedDevices.isNotEmpty) {
        _logger.printStatus(
          'Found ${attachedDevices.length} connected ${pluralize('device', attachedDevices.length)}:',
        );
        await TizenDevice.printDevices(attachedDevices, _logger, prefix: '  ');
        _logger.printStatus('');
        numLinesToClear += 1;
      }

      // Display waiting message.
      if (attachedDevices.isEmpty && _includeAttachedDevices) {
        _logger.printStatus('No devices found yet. Checking for wireless devices...');
      } else {
        _logger.printStatus('Checking for wireless devices...');
      }
      numLinesToClear += 1;

      final Status waitingStatus = _logger.startSpinner();
      await extendedWirelessDiscovery;

      var wirelessDevices = <Device>[];
      if (deviceManager != null) {
        wirelessDevices = await _getWirelessDevices(deviceManager);
      }
      waitingStatus.stop();

      final Terminal terminal = _logger.terminal;
      if (_logger.isVerbose && _includeAttachedDevices) {
        // Reprint the attached devices.
        if (attachedDevices.isNotEmpty) {
          _logger.printStatus(
            '\nFound ${attachedDevices.length} connected ${pluralize('device', attachedDevices.length)}:',
          );
          await TizenDevice.printDevices(attachedDevices, _logger, prefix: '  ');
        }
      } else if (terminal.supportsColor && terminal is AnsiTerminal) {
        _logger.printStatus(terminal.clearLines(numLinesToClear), newline: false);
      }

      if (attachedDevices.isNotEmpty || !_logger.terminal.supportsColor) {
        _logger.printStatus('');
      }

      if (wirelessDevices.isEmpty) {
        if (attachedDevices.isEmpty) {
          _logger.printStatus('No authorized devices detected.');
        } else {
          _logger.printStatus('No wireless devices were found.');
        }
      } else {
        _logger.printStatus(
          'Found ${wirelessDevices.length} wirelessly connected ${pluralize('device', wirelessDevices.length)}:',
        );
        await TizenDevice.printDevices(wirelessDevices, _logger, prefix: '  ');
      }

      await _printDiagnostics(foundAny: wirelessDevices.isNotEmpty || attachedDevices.isNotEmpty);
      return;
    }

    var attachedDevices = <Device>[];
    var wirelessDevices = <Device>[];
    final DeviceManager? deviceManager = _deviceManager;
    if (deviceManager != null) {
      await deviceManager.refreshAllDevices(timeout: deviceDiscoveryTimeout);
      attachedDevices = await _getAttachedDevices(deviceManager);
      wirelessDevices = await _getWirelessDevices(deviceManager);
    }
    final List<Device> allDevices = attachedDevices + wirelessDevices;

    if (machine) {
      await printDevicesAsJson(allDevices);
      return;
    }

    if (allDevices.isEmpty) {
      _logger.printStatus('No authorized devices detected.');
    } else {
      if (attachedDevices.isNotEmpty) {
        _logger.printStatus(
          'Found ${attachedDevices.length} connected ${pluralize('device', attachedDevices.length)}:',
        );
        await TizenDevice.printDevices(attachedDevices, _logger, prefix: '  ');
      }
      if (wirelessDevices.isNotEmpty) {
        if (attachedDevices.isNotEmpty) {
          _logger.printStatus('');
        }
        _logger.printStatus(
          'Found ${wirelessDevices.length} wirelessly connected ${pluralize('device', wirelessDevices.length)}:',
        );
        await TizenDevice.printDevices(wirelessDevices, _logger, prefix: '  ');
      }
    }
    await _printDiagnostics(foundAny: allDevices.isNotEmpty);
  }

  /// Source: [DevicesCommandOutput._printDiagnostics] in `devices.dart`
  Future<void> _printDiagnostics({required bool foundAny}) async {
    final status = StringBuffer();
    status.writeln();
    final List<String> diagnostics = await _deviceManager?.getDeviceDiagnostics() ?? <String>[];
    if (diagnostics.isNotEmpty) {
      for (final diagnostic in diagnostics) {
        status.writeln(diagnostic);
        status.writeln();
      }
    }
    status
        .writeln('Run "flutter-tizen emulators" to list and start any available device emulators.');
    status.writeln();
    status.write(
      'If you expected ${foundAny ? 'another' : 'a'} device to be detected, please run "flutter-tizen doctor" to diagnose potential issues. ',
    );
    if (deviceDiscoveryTimeout == null) {
      status.write(
        'You may also try increasing the time to wait for connected devices with the "--${FlutterOptions.kDeviceTimeout}" flag. ',
      );
    }
    status.write('Visit https://flutter.dev/setup/ for troubleshooting tips.');
    _logger.printStatus(status.toString());
  }

  /// Source: [DevicesCommandOutput.printDevicesAsJson] in `devices.dart`
  Future<void> printDevicesAsJson(List<Device> devices) async {
    _logger.printStatus(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(await Future.wait(devices.map((Device d) => d.toJson()))),
    );
  }
}
