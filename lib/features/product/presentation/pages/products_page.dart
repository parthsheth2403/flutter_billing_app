import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/product_excel_service.dart';
import '../bloc/product_bloc.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  Future<void> _uploadProductsFromExcel(BuildContext context) async {
    final existingProducts = context.read<ProductBloc>().state.products;

    try {
      final result = await ProductExcelService.pickAndParseProducts(
        existingProducts: existingProducts,
      );

      if (!context.mounted || result == null) return;

      if (result.productsToAdd.isEmpty) {
        final message = result.totalRows == 0
            ? 'No product rows found in the selected Excel file.'
            : 'No new products were added. Duplicate or invalid rows were skipped.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      context.read<ProductBloc>().add(
            AddProducts(
              result.productsToAdd,
              message: result.buildSummaryMessage(),
            ),
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      final file = await ProductExcelService.exportProductsTemplate();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel template saved to ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create product template right now.'),
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
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            size: 28,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Product Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _ShortcutCard(
              title: 'Product List',
              subtitle: 'Open product list with search and show all products',
              icon: Icons.list_alt_rounded,
              onTap: () => context.push('/products/list'),
            ),
            _ShortcutCard(
              title: 'Add Product Using Existing QR',
              subtitle: 'Use an already printed QR or barcode',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => context.push('/products/add-with-qr'),
            ),
            _ShortcutCard(
              title: 'Add Product',
              subtitle: 'Create a product with app-generated barcode',
              icon: Icons.add_box_outlined,
              onTap: () => context.push('/products/add'),
            ),
            _ShortcutCard(
              title: 'Upload Products from Excel',
              subtitle: 'Bulk add products without duplicates',
              icon: Icons.upload_file_rounded,
              onTap: () => _uploadProductsFromExcel(context),
              onLongPress: () => _downloadTemplate(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppTheme.textColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textColor,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
