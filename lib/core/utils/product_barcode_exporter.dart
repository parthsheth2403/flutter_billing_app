import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/product/domain/entities/product.dart';

class ProductBarcodeExporter {
  static Future<File> export(List<Product> products) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/product_barcodes_$timestamp.html');

    final sortedProducts = [...products]
      ..sort((first, second) => first.name.compareTo(second.name));

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="UTF-8">')
      ..writeln(
          '<meta name="viewport" content="width=device-width, initial-scale=1.0">')
      ..writeln('<title>Product Barcodes</title>')
      ..writeln('<style>')
      ..writeln(
          'body { font-family: Arial, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #0f172a; }')
      ..writeln('h1 { margin-bottom: 8px; }')
      ..writeln('p { margin-top: 0; color: #475569; }')
      ..writeln(
          '.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; }')
      ..writeln(
          '.card { background: #ffffff; border: 1px solid #dbeafe; border-radius: 16px; padding: 16px; box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06); }')
      ..writeln(
          '.name { font-size: 18px; font-weight: 700; margin-bottom: 6px; }')
      ..writeln(
          '.price { font-size: 16px; color: #1d4ed8; font-weight: 600; margin-bottom: 14px; }')
      ..writeln(
          '.barcode-label { font-size: 12px; letter-spacing: 1.4px; text-transform: uppercase; color: #64748b; margin-bottom: 6px; }')
      ..writeln(
          '.barcode-value { font-family: monospace; font-size: 20px; letter-spacing: 3px; padding: 12px; text-align: center; border: 1px dashed #94a3b8; border-radius: 12px; background: #f8fafc; }')
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<h1>Mahavir Trading Company</h1>')
      ..writeln(
          '<p>Product barcode sheet with item name, price, and barcode number.</p>')
      ..writeln('<div class="grid">');

    for (final product in sortedProducts) {
      buffer
        ..writeln('<div class="card">')
        ..writeln('<div class="name">${_escapeHtml(product.name)}</div>')
        ..writeln(
            '<div class="price">Rs. ${product.price.toStringAsFixed(2)}</div>')
        ..writeln('<div class="barcode-label">Barcode</div>')
        ..writeln(
            '<div class="barcode-value">${_escapeHtml(product.barcode)}</div>')
        ..writeln('</div>');
    }

    buffer
      ..writeln('</div>')
      ..writeln('</body>')
      ..writeln('</html>');

    return file.writeAsString(buffer.toString());
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
