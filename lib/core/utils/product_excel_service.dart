import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/product/domain/entities/product.dart';
import 'barcode_generator.dart';

class ProductImportResult {
  final List<Product> productsToAdd;
  final int totalRows;
  final int addedCount;
  final int duplicateCount;
  final int invalidCount;
  final String fileName;

  const ProductImportResult({
    required this.productsToAdd,
    required this.totalRows,
    required this.addedCount,
    required this.duplicateCount,
    required this.invalidCount,
    required this.fileName,
  });

  String buildSummaryMessage() {
    return '$addedCount product${addedCount == 1 ? '' : 's'} added from '
        '$fileName. $duplicateCount duplicate row${duplicateCount == 1 ? '' : 's'} '
        'skipped, $invalidCount invalid row${invalidCount == 1 ? '' : 's'} ignored.';
  }
}

class ProductExcelService {
  ProductExcelService._();

  static const List<String> _expectedHeaders = <String>[
    'barcodenumber',
    'productid',
    'productname',
    'price',
    'brand',
  ];

  static Future<ProductImportResult?> pickAndParseProducts({
    required List<Product> existingProducts,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('No worksheet found in the selected Excel file.');
    }

    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      throw Exception('Excel file is empty.');
    }

    final headerRow = rows.first;
    final headerMap = <String, int>{};
    for (var index = 0; index < headerRow.length; index++) {
      final normalized =
          _normalizeHeader(_cellToString(headerRow[index]?.value));
      if (normalized.isNotEmpty) {
        headerMap[normalized] = index;
      }
    }

    final hasAllHeaders = _expectedHeaders.every(headerMap.containsKey);
    if (!hasAllHeaders) {
      throw Exception(
        'Excel format is invalid. Use: Barcode Number | Product ID | Product Name | Price | Brand',
      );
    }

    final existingBarcodes = existingProducts
        .map((product) => product.barcode.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final existingProductKeys = existingProducts
        .map((product) => _duplicateKey(product.name, product.brand))
        .toSet();

    final productsToAdd = <Product>[];
    var duplicateCount = 0;
    var invalidCount = 0;
    var totalRows = 0;

    for (final row in rows.skip(1)) {
      if (_isBlankRow(row)) continue;
      totalRows++;

      final barcode = _readValue(row, headerMap['barcodenumber']);
      final name = _readValue(row, headerMap['productname']);
      final priceRaw = _readValue(row, headerMap['price']);
      final brand = _readValue(row, headerMap['brand']);

      final price = double.tryParse(priceRaw.replaceAll(',', ''));
      if (name.isEmpty || price == null || price < 0) {
        invalidCount++;
        continue;
      }

      final normalizedKey = _duplicateKey(name, brand);
      String resolvedBarcode = barcode;
      if (resolvedBarcode.isEmpty) {
        resolvedBarcode =
            BarcodeGenerator.generateProductBarcode(existingBarcodes);
      }

      final isDuplicateBarcode = existingBarcodes.contains(resolvedBarcode);
      final isDuplicateProduct = existingProductKeys.contains(normalizedKey);
      if (isDuplicateBarcode || isDuplicateProduct) {
        duplicateCount++;
        continue;
      }

      productsToAdd.add(
        Product(
          id: const Uuid().v4(),
          name: name,
          barcode: resolvedBarcode,
          price: price,
          brand: brand,
        ),
      );

      existingBarcodes.add(resolvedBarcode);
      existingProductKeys.add(normalizedKey);
    }

    return ProductImportResult(
      productsToAdd: productsToAdd,
      totalRows: totalRows,
      addedCount: productsToAdd.length,
      duplicateCount: duplicateCount,
      invalidCount: invalidCount,
      fileName: file.name,
    );
  }

  static Future<File> exportProductsTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    sheet.appendRow(<CellValue>[
      TextCellValue('Barcode Number'),
      TextCellValue('Product ID'),
      TextCellValue('Product Name'),
      TextCellValue('Price'),
      TextCellValue('Brand'),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Sample Product'),
      const DoubleCellValue(100),
      TextCellValue('Sample Brand'),
    ]);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Unable to create product template right now.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file =
        File('${directory.path}/product_import_template_$timestamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _readValue(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return '';
    return _cellToString(row[index]?.value);
  }

  static String _cellToString(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString().trim(),
      IntCellValue() => value.value.toString().trim(),
      DoubleCellValue() => value.value.toString().trim(),
      BoolCellValue() => (value.value ? 'true' : 'false'),
      DateCellValue() => value.asDateTimeLocal().toIso8601String(),
      DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
      TimeCellValue() => value.asDuration().toString(),
      FormulaCellValue() => value.formula.trim(),
    };
  }

  static bool _isBlankRow(List<Data?> row) {
    return row.every((cell) => _cellToString(cell?.value).trim().isEmpty);
  }

  static String _duplicateKey(String name, String brand) {
    return '${name.trim().toLowerCase()}|${brand.trim().toLowerCase()}';
  }
}
