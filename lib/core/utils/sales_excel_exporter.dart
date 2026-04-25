import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'sales_storage.dart';

class SalesExcelExporter {
  SalesExcelExporter._();

  static Future<File> export({
    required List<Map> sales,
    DateTime? selectedDate,
  }) async {
    final excel = Excel.createExcel();
    final detailSheet = excel['Sales Report'];
    final summarySheet = excel['Product Summary'];

    detailSheet.appendRow(<CellValue>[
      TextCellValue('Bill ID'),
      TextCellValue('Created At'),
      TextCellValue('Payment Mode'),
      TextCellValue('Customer Name'),
      TextCellValue('Product Name'),
      TextCellValue('Barcode'),
      TextCellValue('Quantity'),
      TextCellValue('Unit Price'),
      TextCellValue('Line Total'),
      TextCellValue('GST Rate'),
      TextCellValue('GST Amount'),
      TextCellValue('Bill Total'),
    ]);

    for (final sale in sales) {
      final createdAt = DateTime.tryParse(sale['createdAt']?.toString() ?? '');
      final items = ((sale['items'] as List?) ?? const <dynamic>[]).cast<Map>();
      final customer = sale['customer'] as Map?;

      for (final item in items) {
        detailSheet.appendRow(<CellValue>[
          TextCellValue(sale['id']?.toString() ?? ''),
          TextCellValue(
            createdAt == null
                ? ''
                : DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
          ),
          TextCellValue(sale['paymentMode']?.toString() ?? ''),
          TextCellValue(customer?['name']?.toString() ?? ''),
          TextCellValue(item['productName']?.toString() ?? ''),
          TextCellValue(item['barcode']?.toString() ?? ''),
          DoubleCellValue((item['quantity'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((item['unitPrice'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((item['lineTotal'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((sale['gstRate'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((sale['gstAmount'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((sale['totalAmount'] as num?)?.toDouble() ?? 0),
        ]);
      }
    }

    summarySheet.appendRow(<CellValue>[
      TextCellValue('Product Name'),
      TextCellValue('Barcode'),
      TextCellValue('Quantity Sold'),
      TextCellValue('Sales Amount'),
    ]);

    final summaries = SalesStorage.buildProductPerformance(sales);
    for (final product in summaries) {
      summarySheet.appendRow(<CellValue>[
        TextCellValue(product.productName),
        TextCellValue(product.barcode),
        DoubleCellValue(product.quantitySold),
        DoubleCellValue(product.totalSales),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Unable to export sales report right now.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final suffix = selectedDate == null
        ? DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())
        : DateFormat('yyyyMMdd').format(selectedDate);
    final file = File('${directory.path}/sales_report_$suffix.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
