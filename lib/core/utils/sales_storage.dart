import 'package:flutter/material.dart';

import '../data/hive_database.dart';
import '../utils/printer_helper.dart';
import '../../features/billing/domain/entities/cart_item.dart';
import 'quantity_formatter.dart';

class SalesSnapshot {
  final double todaySales;
  final int todayBills;
  final double monthSales;
  final int monthBills;

  const SalesSnapshot({
    required this.todaySales,
    required this.todayBills,
    required this.monthSales,
    required this.monthBills,
  });
}

class SalesStorage {
  static Future<String> saveSale({
    required List<CartItem> cartItems,
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required String upiId,
    required String footer,
    Map<String, dynamic>? customer,
  }) async {
    final now = DateTime.now();
    final saleId = 'SALE-${now.microsecondsSinceEpoch}';
    final totalAmount =
        cartItems.fold<double>(0, (sum, item) => sum + item.total);

    final sale = <String, dynamic>{
      'id': saleId,
      'shopName': shopName,
      'address1': address1,
      'address2': address2,
      'phone': phone,
      'upiId': upiId,
      'footer': footer,
      'customer': customer,
      'createdAt': now.toIso8601String(),
      'totalAmount': totalAmount,
      'itemCount':
          cartItems.fold<double>(0, (sum, item) => sum + item.quantity),
      'items': cartItems
          .map(
            (item) => <String, dynamic>{
              'productId': item.product.id,
              'productName': item.product.name,
              'barcode': item.product.barcode,
              'quantity': item.quantity,
              'unitPrice': item.product.price,
              'lineTotal': item.total,
            },
          )
          .toList(),
    };

    await HiveDatabase.salesBox.put(saleId, sale);
    return saleId;
  }

  static List<Map> getSales() {
    final sales = HiveDatabase.salesBox.values.toList();
    sales.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sales;
  }

  static Future<void> deleteSale(String saleId) async {
    await HiveDatabase.salesBox.delete(saleId);
  }

  static Future<void> printSavedSale(Map sale) async {
    final printerHelper = PrinterHelper();
    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac == null) {
        throw Exception('Printer not connected & no saved printer found!');
      }

      final connected = await printerHelper.connect(savedMac);
      if (!connected) {
        throw Exception('Failed to auto-connect to printer!');
      }
    }

    final items = ((sale['items'] as List?) ?? [])
        .map(
          (item) => {
            'name': item['productName'],
            'qty': QuantityFormatter.format(item['quantity'] as num? ?? 0),
            'price': item['unitPrice'],
            'total': item['lineTotal'],
          },
        )
        .toList();

    await printerHelper.printReceipt(
      shopName: sale['shopName']?.toString() ?? 'Mahavir Trading Company',
      address1: sale['address1']?.toString() ?? '',
      address2: sale['address2']?.toString() ?? '',
      phone: sale['phone']?.toString() ?? '',
      upiId: sale['upiId']?.toString() ?? '',
      items: items,
      total: (sale['totalAmount'] as num?)?.toDouble() ?? 0,
      footer: sale['footer']?.toString() ?? '',
      createdAt: DateTime.tryParse(sale['createdAt']?.toString() ?? ''),
    );
  }

  static SalesSnapshot buildSnapshot(Iterable<Map> sales) {
    final now = DateTime.now();
    double todaySales = 0;
    double monthSales = 0;
    int todayBills = 0;
    int monthBills = 0;

    for (final sale in sales) {
      final createdAtRaw = sale['createdAt']?.toString();
      final totalAmount = (sale['totalAmount'] as num?)?.toDouble() ?? 0;
      if (createdAtRaw == null) continue;

      final createdAt = DateTime.tryParse(createdAtRaw);
      if (createdAt == null) continue;

      if (DateUtils.isSameDay(createdAt, now)) {
        todaySales += totalAmount;
        todayBills += 1;
      }

      if (createdAt.year == now.year && createdAt.month == now.month) {
        monthSales += totalAmount;
        monthBills += 1;
      }
    }

    return SalesSnapshot(
      todaySales: todaySales,
      todayBills: todayBills,
      monthSales: monthSales,
      monthBills: monthBills,
    );
  }
}
