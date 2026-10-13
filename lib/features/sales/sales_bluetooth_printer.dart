import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin/admin_utils.dart';

/// Sends ESC/POS bytes to a paired Bluetooth thermal printer.
///
/// Flow: request the Bluetooth permission if needed -> make sure Bluetooth is
/// on -> pick a paired printer (the last-used one, or the only one, or a
/// chooser) -> connect -> write the bytes -> disconnect.
class SalesBluetoothPrinter {
  SalesBluetoothPrinter._();

  static const String _prefsKey = 'sales_bt_printer_mac';

  /// Enables Bluetooth and grants the runtime permission (Android 12+).
  static Future<bool> ensureReady() async {
    if (!Platform.isAndroid) return false;
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) return false;
    if (!await PrintBluetoothThermal.bluetoothEnabled) return false;
    return true;
  }

  static Future<List<BluetoothInfo>> pairedDevices() async {
    if (!await ensureReady()) return const [];
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<void> _remember(String mac) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mac);
    } catch (_) {}
  }

  static Future<String?> _lastUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKey);
    } catch (_) {
      return null;
    }
  }

  static Future<BluetoothInfo?> _pick(
    BuildContext context,
    List<BluetoothInfo> devices,
  ) async {
    if (devices.isEmpty) return null;
    if (devices.length == 1) return devices.first;

    final last = await _lastUsed();
    for (final d in devices) {
      if (d.macAdress == last) return d;
    }

    if (!context.mounted) return devices.first;
    return showDialog<BluetoothInfo>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Printer'),
        children: [
          for (final d in devices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(d),
              child: Text(d.name.isEmpty ? d.macAdress : d.name),
            ),
        ],
      ),
    );
  }

  /// Prints [bytes] over Bluetooth. Shows progress/toasts and returns true on
  /// success. [label] is shown in the toasts (e.g. "Sale Receipt #12").
  static Future<bool> printBytes(
    BuildContext context, {
    required List<int> bytes,
    String label = 'Receipt',
  }) async {
    if (!Platform.isAndroid) {
      showToast(context, 'Bluetooth printing is only available on Android.',
          error: true);
      return false;
    }

    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      if (!context.mounted) return false;
      showToast(
        context,
        'Bluetooth permission is required to print. Please allow it and try again.',
        error: true,
      );
      return false;
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      if (!context.mounted) return false;
      showToast(
        context,
        'Please turn on Bluetooth and try again.',
        error: true,
      );
      return false;
    }

    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (!context.mounted) return false;
    if (devices.isEmpty) {
      showToast(
        context,
        'No paired Bluetooth printer found. Pair one in Settings first.',
        error: true,
      );
      return false;
    }

    final printer = await _pick(context, devices);
    if (printer == null) return false;
    if (!context.mounted) return false;

    showToast(
      context,
      'Sending $label to ${printer.name.isEmpty ? printer.macAdress : printer.name}...',
    );

    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress,
      );
    }
    if (!connected) {
      if (context.mounted) {
        showToast(
          context,
          'Could not connect to ${printer.name.isEmpty ? printer.macAdress : printer.name}.',
          error: true,
        );
      }
      return false;
    }

    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    await PrintBluetoothThermal.disconnect;
    if (ok) await _remember(printer.macAdress);

    if (context.mounted) {
      showToast(
        context,
        ok ? '$label printed.' : 'Failed to print $label.',
        error: !ok,
      );
    }
    return ok;
  }
}