import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/shop_access_controller.dart';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';

class BackupSnapshot {
  final String? shopId;
  final int productCount;
  final int customerCount;
  final int saleCount;
  final int expenseCount;

  const BackupSnapshot({
    required this.shopId,
    required this.productCount,
    required this.customerCount,
    required this.saleCount,
    required this.expenseCount,
  });
}

class DataBackupService {
  DataBackupService._();

  static const int _schemaVersion = 1;

  static Future<File> exportBackupFile() async {
    final directory = await getTemporaryDirectory();
    final profileMap = _currentShopProfileMap();
    final shopId = profileMap['shopId']?.toString().trim();
    final shopSuffix = (shopId == null || shopId.isEmpty) ? 'local' : shopId;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file =
        File('${directory.path}/billing_backup_${shopSuffix}_$timestamp.json');

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'shopId': shopId,
      'shopName': profileMap['shopName']?.toString(),
      'products': HiveDatabase.productBox.values
          .map(
            (product) => <String, dynamic>{
              'id': product.id,
              'name': product.name,
              'barcode': product.barcode,
              'price': product.price,
              'brand': product.brand,
              'stock': product.stock,
            },
          )
          .toList(),
      'shop': HiveDatabase.shopBox.toMap().map(
            (key, value) => MapEntry(
              key.toString(),
              <String, dynamic>{
                'name': value.name,
                'addressLine1': value.addressLine1,
                'addressLine2': value.addressLine2,
                'phoneNumber': value.phoneNumber,
                'upiId': value.upiId,
                'footerText': value.footerText,
              },
            ),
          ),
      'settings': _normalizeValue(HiveDatabase.settingsBox.toMap()),
      'sales': _normalizeBoxEntries(HiveDatabase.salesBox),
      'customers': _normalizeBoxEntries(HiveDatabase.customerBox),
      'expenses': _normalizeBoxEntries(HiveDatabase.expenseBox),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return file;
  }

  static Future<void> shareBackupFile() async {
    final file = await exportBackupFile();
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'Billing app backup file',
        subject: 'Billing App Backup',
      ),
    );
  }

  static Future<BackupSnapshot?> pickAndImportBackup() async {
    return pickAndImportBackupForShop();
  }

  static Future<BackupSnapshot?> pickAndImportBackupForShop({
    String? expectedShopId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    if (file.bytes != null) {
      final content = utf8.decode(file.bytes!);
      return importBackupContent(
        content,
        expectedShopId: expectedShopId,
      );
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw Exception('Unable to read the selected backup file.');
    }

    final content = await File(path).readAsString();
    return importBackupContent(
      content,
      expectedShopId: expectedShopId,
    );
  }

  static Future<BackupSnapshot> importBackupContent(
    String content, {
    String? expectedShopId,
  }) async {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw Exception('Invalid backup format.');
    }

    final backup = Map<String, dynamic>.from(decoded);
    final version = backup['schemaVersion'];
    if (version is! int || version > _schemaVersion) {
      throw Exception('This backup file version is not supported.');
    }

    final backupShopId = backup['shopId']?.toString().trim();
    if (expectedShopId != null &&
        expectedShopId.trim().isNotEmpty &&
        backupShopId != null &&
        backupShopId.isNotEmpty &&
        backupShopId != expectedShopId.trim()) {
      throw Exception(
        'This backup belongs to shop ID $backupShopId, not ${expectedShopId.trim()}.',
      );
    }

    final products = ((backup['products'] as List?) ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final shop = Map<String, dynamic>.from(
      (backup['shop'] as Map?) ?? const <dynamic, dynamic>{},
    );
    final settings = Map<String, dynamic>.from(
      (backup['settings'] as Map?) ?? const <dynamic, dynamic>{},
    );
    final sales = ((backup['sales'] as List?) ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final customers = ((backup['customers'] as List?) ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final expenses = ((backup['expenses'] as List?) ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    await HiveDatabase.productBox.clear();
    for (final product in products) {
      final model = ProductModel(
        id: product['id']?.toString() ?? '',
        name: product['name']?.toString() ?? '',
        barcode: product['barcode']?.toString() ?? '',
        price: (product['price'] as num?)?.toDouble() ?? 0,
        stock: (product['stock'] as num?)?.toInt() ?? 0,
        brand: product['brand']?.toString() ?? '',
      );
      await HiveDatabase.productBox.put(model.id, model);
    }

    await HiveDatabase.shopBox.clear();
    for (final entry in shop.entries) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      final model = ShopModel(
        name: value['name']?.toString() ?? '',
        addressLine1: value['addressLine1']?.toString() ?? '',
        addressLine2: value['addressLine2']?.toString() ?? '',
        phoneNumber: value['phoneNumber']?.toString() ?? '',
        upiId: value['upiId']?.toString() ?? '',
        footerText: value['footerText']?.toString() ?? '',
      );
      await HiveDatabase.shopBox.put(entry.key, model);
    }

    await HiveDatabase.settingsBox.clear();
    for (final entry in settings.entries) {
      await HiveDatabase.settingsBox.put(entry.key, entry.value);
    }

    await HiveDatabase.salesBox.clear();
    for (final entry in sales) {
      final key = entry['key']?.toString() ?? '';
      final value = Map<String, dynamic>.from(entry['value'] as Map);
      await HiveDatabase.salesBox.put(key, value);
    }

    await HiveDatabase.customerBox.clear();
    for (final entry in customers) {
      final key = entry['key']?.toString() ?? '';
      final value = Map<String, dynamic>.from(entry['value'] as Map);
      await HiveDatabase.customerBox.put(key, value);
    }

    await HiveDatabase.expenseBox.clear();
    for (final entry in expenses) {
      final key = entry['key']?.toString() ?? '';
      final value = Map<String, dynamic>.from(entry['value'] as Map);
      await HiveDatabase.expenseBox.put(key, value);
    }

    return BackupSnapshot(
      shopId: backupShopId,
      productCount: products.length,
      customerCount: customers.length,
      saleCount: sales.length,
      expenseCount: expenses.length,
    );
  }

  static Map<String, dynamic> _currentShopProfileMap() {
    final rawProfile = HiveDatabase.settingsBox.get('shop_access_profile');
    if (rawProfile is Map) {
      return Map<String, dynamic>.from(rawProfile);
    }

    final profile = ShopAccessController.instance.profile;
    if (profile != null) {
      return profile.toMap();
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _normalizeBoxEntries(Box<Map> box) {
    return box.toMap().entries.map((entry) {
      return <String, dynamic>{
        'key': entry.key.toString(),
        'value': _normalizeValue(Map<String, dynamic>.from(entry.value)),
      };
    }).toList();
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Uint8List) {
      return base64Encode(value);
    }

    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _normalizeValue(nestedValue),
        ),
      );
    }

    if (value is Iterable) {
      return value.map(_normalizeValue).toList();
    }

    return value.toString();
  }
}
