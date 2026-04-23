import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textLarge = [0x1D, 0x21, 0x11];
  static const List<int> lineFeed = [0x0A];
  static const List<int> barcodeTextBelow = [0x1D, 0x48, 0x02];
  static const List<int> barcodeTextOff = [0x1D, 0x48, 0x00];
  static const List<int> barcodeFontA = [0x1D, 0x66, 0x00];
  static const List<int> barcodeHeight = [0x1D, 0x68, 0x50];
  static const List<int> barcodeWidth = [0x1D, 0x77, 0x02];
}

class PrinterHelper {
  // Singleton
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<bool> connectionStatus() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      _isConnected = status;
      return status;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> checkPermission() async {
    // Request Bluetooth and Location permissions
    // Android 12+ needs BLUETOOTH_SCAN, BLUETOOTH_CONNECT
    // Older Android needs BLUETOOTH, BLUETOOTH_ADMIN, ACCESS_FINE_LOCATION

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    if (macAddress.trim().isEmpty) {
      _isConnected = false;
      return false;
    }

    try {
      final hasActiveConnection = await connectionStatus();
      if (hasActiveConnection) {
        await PrintBluetoothThermal.disconnect;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final activeConnection = await connectionStatus();
      _isConnected = result && activeConnection;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final activeConnection = await connectionStatus();
      if (!activeConnection) {
        _isConnected = false;
        return true;
      }

      final result = await PrintBluetoothThermal.disconnect;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final stillConnected = await connectionStatus();
      _isConnected = stillConnected;
      return result || !stillConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<void> printText(String text) async {
    if (!await connectionStatus()) return;

    // Simple text printing
    // We can use bytes for advanced formatting
    // But plugin supports basic text or bytes

    // Checking battery or connection status
    final activeConnection = await connectionStatus();
    if (activeConnection) {
      // Plugin allows sending bytes. We need ESC/POS commands for text.
      // However, the plugin might have helper.
      // Looking at doc, `writeBytes` or `writeString`?
      // The plugin `print_bluetooth_thermal` mainly exposes `writeBytes`.
      // We need a generator. `esc_pos_utils` is common but not requested.
      // But wait, `print_bluetooth_thermal` example often uses `capability_profile` and `generator`.
      // I don't have `esc_pos_utils` or similar in my pubspec.
      // The user requested `print_bluetooth_thermal`.
      // Let's assume we can send raw string bytes or use a simple helper.
      // Actually without `esc_pos_utils`, formatting is hard.
      // I will try to use `esc_pos_utils_plus` or similar if I can add it, but user gave specific packages.
      // Wait, user allowed "use required plugins".
      // "suggest barcode scanner ... and use required plugins".
      // So I can add `esc_pos_utils_plus`.

      // For now, I'll assume simple text printing by converting string to bytes.
      // ASCII bytes.
      List<int> bytes = text.codeUnits;
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required String upiId,
    required List<Map<String, dynamic>> items, // Name, Qty, Price, Total
    double? subtotal,
    double discount = 0,
    required double total,
    required String footer,
    Map<String, dynamic>? customer,
    DateTime? createdAt,
  }) async {
    if (!await connectionStatus()) return;

    // Construct ESC/POS bytes manually or using helper
    List<int> bytes = [];

    // Init
    bytes += EscPos.init;

    // Shop Name (Center, Bold, Large)
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(shopName);
    bytes += EscPos.lineFeed;

    // Address & Phone (Normal, Center)
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    final addressLines = [
      address1.trim(),
      address2.trim(),
    ].where((line) => line.isNotEmpty).toList();
    if (addressLines.isNotEmpty) {
      bytes += _textToBytes('Add: ${addressLines.join(', ')}');
      bytes += EscPos.lineFeed;
    }
    if (phone.trim().isNotEmpty) {
      bytes += _textToBytes('Mob: ${phone.trim()}');
      bytes += EscPos.lineFeed;
    }

    // Date and Time
    String formattedDate =
        DateFormat('dd-MM-yyyy hh:mm a').format(createdAt ?? DateTime.now());
    bytes += _textToBytes(formattedDate);
    bytes += EscPos.lineFeed;

    if (customer != null) {
      final customerName = customer['name']?.toString().trim() ?? '';
      final customerMobile = customer['mobile']?.toString().trim() ?? '';
      if (customerName.isNotEmpty || customerMobile.isNotEmpty) {
        bytes += _textToBytes('--------------------------------');
        bytes += EscPos.lineFeed;
        if (customerName.isNotEmpty) {
          bytes += _textToBytes('Customer: $customerName');
          bytes += EscPos.lineFeed;
        }
        if (customerMobile.isNotEmpty) {
          bytes += _textToBytes('Mobile: $customerMobile');
          bytes += EscPos.lineFeed;
        }
      }
    }

    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Header (Align Left)
    bytes += EscPos.alignLeft;
    bytes += _textToBytes('Item          Price     Total');
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Items
    for (var item in items) {
      final name = item['name'].toString().trim();
      final qty = item['qty'].toString().trim();
      final price = _formatAmount(item['price']);
      final totalItem = _formatAmount(item['total']);

      final nameLines = _wrapText('${qty}x $name', 14);
      final firstNameLine = nameLines.isEmpty ? '' : nameLines.first;
      bytes += _textToBytes(
        firstNameLine.padRight(14) + price.padLeft(8) + totalItem.padLeft(10),
      );
      bytes += EscPos.lineFeed;

      for (final continuation in nameLines.skip(1)) {
        bytes += _textToBytes('  $continuation');
        bytes += EscPos.lineFeed;
      }
    }

    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Total (Align Right)
    bytes += EscPos.alignRight;
    if (discount > 0) {
      final subtotalAmount = subtotal ?? total + discount;
      bytes += _textToBytes('SUBTOTAL: ${subtotalAmount.toStringAsFixed(2)}');
      bytes += EscPos.lineFeed;
      bytes += _textToBytes('DISCOUNT: -${discount.toStringAsFixed(2)}');
      bytes += EscPos.lineFeed;
    }
    bytes += EscPos.boldOn;
    bytes += _textToBytes('TOTAL: ${total.toStringAsFixed(2)}');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOff;
    bytes += EscPos.lineFeed;

    if (upiId.trim().isNotEmpty) {
      final upiPayload = _buildUpiPayload(
        upiId: upiId,
        shopName: shopName,
        total: total,
      );

      bytes += EscPos.alignCenter;
      bytes += EscPos.boldOn;
      bytes += _textToBytes('SCAN & PAY');
      bytes += EscPos.lineFeed;
      bytes += EscPos.boldOff;
      bytes += _textToBytes('UPI: ${upiId.trim()}');
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      bytes += _qrCodeBytes(upiPayload);
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
    }

    // Footer (Center)
    bytes += EscPos.alignCenter;
    bytes += _textToBytes(footer);
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed; // One line space after footer
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed; // Additional Feed

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printProductBarcodeLabels({
    required String productName,
    required String barcode,
    required double price,
    required int quantity,
  }) async {
    if (!await connectionStatus()) return;

    final safeQuantity = quantity < 1 ? 1 : quantity;
    final barcodePayload = _code128Bytes(barcode.trim());

    List<int> bytes = [];
    bytes += EscPos.init;

    for (var index = 0; index < safeQuantity; index++) {
      bytes += EscPos.alignCenter;
      bytes += EscPos.barcodeTextBelow;
      bytes += EscPos.barcodeFontA;
      bytes += EscPos.barcodeHeight;
      bytes += EscPos.barcodeWidth;
      bytes += barcodePayload;
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
    }

    bytes += EscPos.barcodeTextOff;
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printPaymentQr({
    required String shopName,
    required String upiId,
    required double amount,
  }) async {
    if (!await connectionStatus()) return;

    final upiPayload = _buildUpiPayload(
      upiId: upiId,
      shopName: shopName,
      total: amount,
    );

    List<int> bytes = [];
    bytes += EscPos.init;
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += _textToBytes('SCAN & PAY');
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOff;
    bytes += _textToBytes(shopName.trim().isEmpty ? 'Shop' : shopName.trim());
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('Amount: ${amount.toStringAsFixed(2)}');
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('UPI: ${upiId.trim()}');
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += _qrCodeBytes(upiPayload);
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  List<int> _textToBytes(String text) {
    // Should verify encoding, but Latin-1 usually works for basic printers
    return List.from(text.codeUnits);
  }

  List<String> _wrapText(String text, int maxLength) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const <String>[];

    final words = normalized.split(' ');
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (word.length > maxLength) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        for (var index = 0; index < word.length; index += maxLength) {
          final end =
              index + maxLength > word.length ? word.length : index + maxLength;
          lines.add(word.substring(index, end));
        }
      } else if (current.isEmpty) {
        current = word;
      } else if (current.length + word.length + 1 <= maxLength) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
  }

  String _formatAmount(dynamic value) {
    if (value is num) return value.toDouble().toStringAsFixed(2);
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed.toStringAsFixed(2);
    return value?.toString() ?? '';
  }

  String _buildUpiPayload({
    required String upiId,
    required String shopName,
    required double total,
  }) {
    final compactShopName = shopName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final shortShopName = compactShopName.length <= 18
        ? compactShopName
        : compactShopName.substring(0, 18);

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: <String, String>{
        'pa': upiId.trim(),
        'pn': shortShopName.isEmpty ? 'Shop' : shortShopName,
        'am': total.toStringAsFixed(2),
        'cu': 'INR',
      },
    ).toString();
  }

  List<int> _qrCodeBytes(String payload) {
    final data = utf8.encode(payload);
    final storeLength = data.length + 3;
    const moduleSize = 6;
    const errorCorrectionLow = 0x30;

    return <int>[
      // QR model 2 is the most widely supported mode for ESC/POS printers.
      0x1D,
      0x28,
      0x6B,
      0x04,
      0x00,
      0x31,
      0x41,
      0x32,
      0x00,
      // Module size. 6 is safer for 58mm printers and avoids QR clipping.
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x43,
      moduleSize,
      // Low correction is the most compatible across low-cost thermal printers.
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x45,
      errorCorrectionLow,
      0x1D,
      0x28,
      0x6B,
      storeLength & 0xFF,
      (storeLength >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
      ...data,
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x51,
      0x30,
    ];
  }

  List<int> _code128Bytes(String value) {
    final payload = '{B$value';
    return <int>[
      0x1D,
      0x6B,
      0x49,
      payload.length,
      ...payload.codeUnits,
    ];
  }
}
