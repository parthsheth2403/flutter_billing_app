import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/expense_storage.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  static const List<String> _categories = <String>[
    'General',
    'Purchase',
    'Salary',
    'Rent',
    'Transport',
    'Tea',
    'Utilities',
    'Other',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedDateFilter = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Expenses'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: HiveDatabase.expenseBox.listenable(),
          builder: (context, box, _) {
            final expenses = ExpenseStorage.getExpenses();
            final filteredExpenses = _filterExpenses(expenses);
            final todayTotal = ExpenseStorage.totalForToday(expenses);
            final monthTotal = ExpenseStorage.totalForMonth(expenses);
            final filteredTotal = ExpenseStorage.totalAmount(filteredExpenses);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _ExpenseSummaryCard(
                  todayTotal: todayTotal,
                  monthTotal: monthTotal,
                  filteredTotal: filteredTotal,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showExpenseForm(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Expense'),
                ),
                const SizedBox(height: 16),
                _SearchAndFilters(
                  controller: _searchController,
                  query: _searchQuery,
                  selectedDateFilter: _selectedDateFilter,
                  selectedCategory: _selectedCategory,
                  categories: _categories,
                  onQueryChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  onDateFilterChanged: (value) {
                    setState(() => _selectedDateFilter = value);
                  },
                  onCategoryChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Expense List',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Text(
                      '${filteredExpenses.length} item${filteredExpenses.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.mutedTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (expenses.isEmpty)
                  const _EmptyExpenseMessage(
                    message: 'No expenses added yet.',
                  )
                else if (filteredExpenses.isEmpty)
                  const _EmptyExpenseMessage(
                    message: 'No expenses match this search.',
                  )
                else
                  ...filteredExpenses.map(
                    (expense) => _ExpenseCard(
                      expense: expense,
                      onEdit: () => _showExpenseForm(
                        context,
                        expense: expense,
                      ),
                      onDelete: () => _deleteExpense(context, expense),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Map> _filterExpenses(List<Map> expenses) {
    final now = DateTime.now();
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    return expenses.where((expense) {
      final date = DateTime.tryParse(expense['expenseDate']?.toString() ?? '');
      final category = _expenseCategory(expense);

      final matchesDate = switch (_selectedDateFilter) {
        'Today' => date != null && DateUtils.isSameDay(date, now),
        'This Month' =>
          date != null && date.year == now.year && date.month == now.month,
        _ => true,
      };

      final matchesCategory =
          _selectedCategory == 'All' || category == _selectedCategory;

      final searchable = [
        expense['title']?.toString() ?? '',
        expense['note']?.toString() ?? '',
        category,
      ].join(' ').toLowerCase();
      final matchesSearch =
          normalizedQuery.isEmpty || searchable.contains(normalizedQuery);

      return matchesDate && matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _showExpenseForm(
    BuildContext context, {
    Map? expense,
  }) async {
    final isEditing = expense != null;
    final titleController = TextEditingController(
      text: expense?['title']?.toString() ?? '',
    );
    final amount = (expense?['amount'] as num?)?.toDouble();
    final amountController = TextEditingController(
      text: amount == null ? '' : amount.toStringAsFixed(2),
    );
    final noteController = TextEditingController(
      text: expense?['note']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var selectedCategory = _expenseCategory(expense);
    if (!_categories.contains(selectedCategory)) {
      selectedCategory = 'General';
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isEditing ? 'Edit Expense' : 'Add Expense',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: _categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Expense Title',
                          hintText: 'e.g. Tea, Transport, Rent',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter expense title'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                        ),
                        validator: (value) {
                          final amount = double.tryParse(value ?? '');
                          if (amount == null || amount <= 0) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            if (isEditing) {
                              await ExpenseStorage.updateExpense(
                                id: expense['id']?.toString() ?? '',
                                title: titleController.text,
                                amount: double.parse(amountController.text),
                                category: selectedCategory,
                                note: noteController.text,
                              );
                            } else {
                              await ExpenseStorage.saveExpense(
                                title: titleController.text,
                                amount: double.parse(amountController.text),
                                category: selectedCategory,
                                note: noteController.text,
                              );
                            }

                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: Text(
                            isEditing ? 'Update Expense' : 'Save Expense',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteExpense(BuildContext context, Map expense) async {
    final expenseId = expense['id']?.toString();
    if (expenseId == null || expenseId.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text(
              'Delete ${expense['title']?.toString() ?? 'this expense'}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await ExpenseStorage.deleteExpense(expenseId);
  }

  static String _expenseCategory(Map? expense) {
    final value = expense?['category']?.toString().trim();
    return value == null || value.isEmpty ? 'General' : value;
  }
}

class _SearchAndFilters extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final String selectedDateFilter;
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onDateFilterChanged;
  final ValueChanged<String> onCategoryChanged;

  const _SearchAndFilters({
    required this.controller,
    required this.query,
    required this.selectedDateFilter,
    required this.selectedCategory,
    required this.categories,
    required this.onQueryChanged,
    required this.onDateFilterChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8E1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search expense, note, category',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['All', 'Today', 'This Month'].map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: selectedDateFilter == filter,
                  onSelected: (_) => onDateFilterChanged(filter),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category Filter',
            ),
            items: <String>['All', ...categories]
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onCategoryChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _ExpenseSummaryCard extends StatelessWidget {
  final double todayTotal;
  final double monthTotal;
  final double filteredTotal;

  const _ExpenseSummaryCard({
    required this.todayTotal,
    required this.monthTotal,
    required this.filteredTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryAmount(
                  title: 'Today',
                  amount: todayTotal,
                ),
              ),
              Container(
                width: 1,
                height: 54,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _SummaryAmount(
                  title: 'This Month',
                  amount: monthTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  'Filtered Total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹ ${filteredTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  final String title;
  final double amount;

  const _SummaryAmount({
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${amount.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Map expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final expenseDate =
        DateTime.tryParse(expense['expenseDate']?.toString() ?? '') ??
            DateTime.now();
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final note = expense['note']?.toString() ?? '';
    final category = expense['category']?.toString().trim().isEmpty ?? true
        ? 'General'
        : expense['category'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expense['title']?.toString() ?? 'Expense',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    DateFormat('dd MMM yyyy, hh:mm a').format(expenseDate),
                    if (note.trim().isNotEmpty) note.trim(),
                  ].join('\n'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.mutedTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyExpenseMessage extends StatelessWidget {
  final String message;

  const _EmptyExpenseMessage({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 42),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppTheme.mutedTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
