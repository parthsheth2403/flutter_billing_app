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
    required double total,
    required String footer,
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
    if (address1.isNotEmpty) {
      bytes += _textToBytes(address1);
      bytes += EscPos.lineFeed;
    }
    if (address2.isNotEmpty) {
      bytes += _textToBytes(address2);
      bytes += EscPos.lineFeed;
    }
    bytes += _textToBytes(phone);
    bytes += EscPos.lineFeed;

    // Date and Time
    String formattedDate =
        DateFormat('dd-MM-yyyy hh:mm a').format(createdAt ?? DateTime.now());
    bytes += _textToBytes(formattedDate);
    bytes += EscPos.lineFeed;

    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Header (Align Left)
    bytes += EscPos.alignLeft;
    bytes += _textToBytes('Item            Price   Total');
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Items
    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = item['price'].toString();
      String totalItem = item['total'].toString();

      String prefix = '${qty}x $name';
      if (prefix.length > 16) prefix = prefix.substring(0, 16);

      String line = prefix.padRight(16) + price.padRight(8) + totalItem;
      bytes += _textToBytes(line);
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Total (Align Right)
    bytes += EscPos.alignRight;
    bytes += EscPos.boldOn;
    bytes += _textToBytes('TOTAL: $total');
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
      bytes += _qrCodeBytes(upiPayload);
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

  List<int> _textToBytes(String text) {
    // Should verify encoding, but Latin-1 usually works for basic printers
    return List.from(text.codeUnits);
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

    return <int>[
      0x1D,
      0x28,
      0x6B,
      0x04,
      0x00,
      0x31,
      0x41,
      0x32,
      0x00,
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x43,
      0x08,
      0x1D,
      0x28,
      0x6B,
      0x03,
      0x00,
      0x31,
      0x45,
      0x30,
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
