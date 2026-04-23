import 'package:flutter/material.dart';

import '../data/hive_database.dart';

class ExpenseStorage {
  static Future<String> saveExpense({
    required String title,
    required double amount,
    String note = '',
    String category = 'General',
    DateTime? expenseDate,
  }) async {
    final now = DateTime.now();
    final expenseId = 'EXP-${now.microsecondsSinceEpoch}';
    final safeAmount = amount.isFinite && amount > 0 ? amount : 0.0;

    final expense = <String, dynamic>{
      'id': expenseId,
      'title': title.trim(),
      'amount': safeAmount,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'note': note.trim(),
      'expenseDate': (expenseDate ?? now).toIso8601String(),
      'createdAt': now.toIso8601String(),
    };

    await HiveDatabase.expenseBox.put(expenseId, expense);
    return expenseId;
  }

  static Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    String note = '',
    String category = 'General',
    DateTime? expenseDate,
  }) async {
    final existing = HiveDatabase.expenseBox.get(id);
    if (existing == null) return;

    final safeAmount = amount.isFinite && amount > 0 ? amount : 0.0;
    final updated = Map<String, dynamic>.from(existing)
      ..['title'] = title.trim()
      ..['amount'] = safeAmount
      ..['category'] = category.trim().isEmpty ? 'General' : category.trim()
      ..['note'] = note.trim()
      ..['expenseDate'] = (expenseDate ??
              DateTime.tryParse(existing['expenseDate']?.toString() ?? '') ??
              DateTime.now())
          .toIso8601String()
      ..['updatedAt'] = DateTime.now().toIso8601String();

    await HiveDatabase.expenseBox.put(id, updated);
  }

  static List<Map> getExpenses() {
    final expenses = HiveDatabase.expenseBox.values.toList();
    expenses.sort((a, b) {
      final aDate = DateTime.tryParse(a['expenseDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['expenseDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return expenses;
  }

  static Future<void> deleteExpense(String expenseId) async {
    await HiveDatabase.expenseBox.delete(expenseId);
  }

  static double totalForToday(Iterable<Map> expenses) {
    final now = DateTime.now();
    return expenses.fold<double>(0, (sum, expense) {
      final date = DateTime.tryParse(expense['expenseDate']?.toString() ?? '');
      if (date == null || !DateUtils.isSameDay(date, now)) return sum;
      return sum + ((expense['amount'] as num?)?.toDouble() ?? 0);
    });
  }

  static double totalForMonth(Iterable<Map> expenses) {
    final now = DateTime.now();
    return expenses.fold<double>(0, (sum, expense) {
      final date = DateTime.tryParse(expense['expenseDate']?.toString() ?? '');
      if (date == null || date.year != now.year || date.month != now.month) {
        return sum;
      }
      return sum + ((expense['amount'] as num?)?.toDouble() ?? 0);
    });
  }

  static double totalAmount(Iterable<Map> expenses) {
    return expenses.fold<double>(0, (sum, expense) {
      return sum + ((expense['amount'] as num?)?.toDouble() ?? 0);
    });
  }
}
