import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/utils/sales_excel_exporter.dart';
import '../../../../core/utils/sales_storage.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _exportSalesReport(List<Map> sales) async {
    if (sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales available for export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final file = await SalesExcelExporter.export(
        sales: sales,
        selectedDate: _selectedDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sales report saved to ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sales'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: HiveDatabase.salesBox.listenable(),
          builder: (context, box, _) {
            final sales = SalesStorage.getSales();
            final filteredSales = _selectedDate == null
                ? sales
                : sales.where((sale) {
                    final createdAt = DateTime.tryParse(
                      sale['createdAt']?.toString() ?? '',
                    );
                    return createdAt != null &&
                        DateUtils.isSameDay(createdAt, _selectedDate);
                  }).toList();
            final snapshot = SalesStorage.buildSnapshot(sales);
            final productSummary =
                SalesStorage.buildProductPerformance(filteredSales);
            final filteredTotal = filteredSales.fold<double>(
              0,
              (sum, sale) =>
                  sum + ((sale['totalAmount'] as num?)?.toDouble() ?? 0),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SalesSummaryCard(
                        title: "Today's Sales",
                        value: '₹${snapshot.todaySales.toStringAsFixed(2)}',
                        subtitle: '${snapshot.todayBills} bills',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SalesSummaryCard(
                        title: 'This Month',
                        value: '₹${snapshot.monthSales.toStringAsFixed(2)}',
                        subtitle: '${snapshot.monthBills} bills',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Previous Bills',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _exportSalesReport(filteredSales),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.table_view_rounded,
                                size: 18,
                              ),
                              label: const Text('Export Excel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _selectedDate == null
                                    ? 'Pick Date'
                                    : DateFormat('dd MMM yyyy')
                                        .format(_selectedDate!),
                              ),
                            ),
                            if (_selectedDate != null)
                              IconButton(
                                onPressed: () =>
                                    setState(() => _selectedDate = null),
                                icon: const Icon(Icons.close),
                                tooltip: 'Clear date filter',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedDate != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined,
                            color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${filteredSales.length} bill${filteredSales.length == 1 ? '' : 's'} on ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹${filteredTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (productSummary.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Product Quantity Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This helps you understand which products moved the most.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 14),
                        ...productSummary.take(5).map(
                            (item) => _ProductSalesSummaryTile(item: item)),
                      ],
                    ),
                  ),
                ],
                if (filteredSales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No saved bills found for this selection.'),
                    ),
                  )
                else
                  ...filteredSales.map((sale) => _SavedBillCard(sale: sale)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductSalesSummaryTile extends StatelessWidget {
  final ProductSalesSummary item;

  const _ProductSalesSummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final quantity = item.quantitySold;
    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.barcode.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.barcode,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$quantityLabel qty',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${item.totalSales.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _SalesSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _SavedBillCard extends StatelessWidget {
  final Map sale;

  const _SavedBillCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(sale['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final total = (sale['totalAmount'] as num?)?.toDouble() ?? 0;
    final itemCount = (sale['itemCount'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        onTap: () => _openBillDetails(context, sale),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          sale['id']?.toString() ?? 'Saved Bill',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)}\n${itemCount.toStringAsFixed(itemCount == itemCount.roundToDouble() ? 0 : 1)} units',
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Icon(Icons.chevron_right, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  void _openBillDetails(BuildContext context, Map sale) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesBillDetailsPage(sale: sale),
      ),
    );
  }
}

class SalesBillDetailsPage extends StatelessWidget {
  final Map sale;

  const SalesBillDetailsPage({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(sale['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final total = (sale['totalAmount'] as num?)?.toDouble() ?? 0;
    final subtotal = (sale['subtotalAmount'] as num?)?.toDouble() ?? total;
    final discount = (sale['discountAmount'] as num?)?.toDouble() ?? 0;
    final gstAmount = (sale['gstAmount'] as num?)?.toDouble() ?? 0;
    final gstRate = (sale['gstRate'] as num?)?.toDouble() ?? 0;
    final items = ((sale['items'] as List?) ?? []).cast<Map>();
    final customer = sale['customer'] as Map?;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bill Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale['shopName']?.toString() ?? 'Your Shop Name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sale['id']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if ((sale['phone']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sale['phone'].toString(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailStatCard(
                          label: 'Items',
                          value:
                              '${(sale['itemCount'] as num?)?.toDouble() ?? 0}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DetailStatCard(
                          label: 'Total',
                          value: '₹${total.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  if (discount > 0 || gstAmount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _AmountBreakupRow(
                            label: 'Subtotal',
                            value: '₹${subtotal.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _AmountBreakupRow(
                            label: 'Discount',
                            value: '- ₹${discount.toStringAsFixed(2)}',
                            valueColor: const Color(0xFF16A34A),
                          ),
                          if (gstAmount > 0) ...[
                            const SizedBox(height: 8),
                            _AmountBreakupRow(
                              label:
                                  'GST (${gstRate.toStringAsFixed(gstRate == gstRate.roundToDouble() ? 0 : 2)}%)',
                              value: '₹${gstAmount.toStringAsFixed(2)}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (customer != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(customer['name']?.toString() ?? ''),
                    if ((customer['mobile']?.toString() ?? '').isNotEmpty)
                      Text(customer['mobile'].toString()),
                    if ((customer['address']?.toString() ?? '').isNotEmpty)
                      Text(customer['address'].toString()),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Sold Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...items.map((item) => _BillItemCard(item: item)),
            if ((sale['footer']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Footer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(sale['footer'].toString()),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: PrimaryButton(
                onPressed: () => _deleteBill(context),
                icon: Icons.delete_outline,
                label: 'Delete Bill',
              ),
            ),
            Expanded(
              child: PrimaryButton(
                onPressed: () => _printBill(context),
                icon: Icons.print,
                label: 'Print Bill',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBill(BuildContext context) async {
    final saleId = sale['id']?.toString();
    if (saleId == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Bill'),
            content: const Text('Do you want to permanently delete this bill?'),
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

    if (!confirmed || !context.mounted) return;

    await SalesStorage.deleteSale(saleId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill deleted'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _printBill(BuildContext context) async {
    try {
      await SalesStorage.printSavedSale(sale);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _DetailStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountBreakupRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _AmountBreakupRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _BillItemCard extends StatelessWidget {
  final Map item;

  const _BillItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
    final lineTotal = (item['lineTotal'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['productName']?.toString() ?? 'Item',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Barcode: ${item['barcode']?.toString() ?? '-'}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${qty == qty.roundToDouble() ? qty.toInt() : qty} x ₹${unitPrice.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Text(
                '₹${lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
