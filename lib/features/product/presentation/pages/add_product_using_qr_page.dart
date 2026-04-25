import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class AddProductUsingQrPage extends StatefulWidget {
  const AddProductUsingQrPage({super.key});

  @override
  State<AddProductUsingQrPage> createState() => _AddProductUsingQrPageState();
}

class _AddProductUsingQrPageState extends State<AddProductUsingQrPage> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final barcode = await context.push<String>('/billing/scanner');
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    await _applyBarcode(barcode.trim());
  }

  Future<void> _applyBarcode(String barcode) async {
    final existingProduct = _findProductByBarcode(barcode);
    if (existingProduct != null) {
      await _showDuplicateAlert(existingProduct);
      _barcodeController.clear();
      return;
    }

    setState(() {
      _barcodeController.text = barcode;
    });
  }

  Product? _findProductByBarcode(String barcode) {
    final products = context.read<ProductBloc>().state.products;
    return products.where((product) => product.barcode == barcode).firstOrNull;
  }

  Future<void> _showDuplicateAlert(Product product) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product already exists'),
        content: Text(
          '${product.name} is already saved with this QR/barcode.\n\n'
          'Price: ₹${product.price.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final barcode = _barcodeController.text.trim();
    final existingProduct = _findProductByBarcode(barcode);
    if (existingProduct != null) {
      _showDuplicateAlert(existingProduct);
      return;
    }

    final product = Product(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      barcode: barcode,
      price: double.parse(_priceController.text.trim()),
    );

    context.read<ProductBloc>().add(AddProduct(product));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            size: 28,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Add Product Using Existing QR',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InputLabel(text: 'Existing QR / Barcode'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          hintText: 'Scan or enter existing QR/barcode',
                        ),
                        validator:
                            AppValidators.required('Please enter a barcode'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'If this QR is already linked to a product, the app will stop duplicate creation.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4C669A)),
                ),
                const SizedBox(height: 24),
                const InputLabel(text: 'Product Name'),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required('Please enter a name'),
                ),
                const SizedBox(height: 24),
                const InputLabel(text: 'Selling Price'),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: '₹ ',
                  ),
                  validator: AppValidators.price,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: PrimaryButton(
          onPressed: _submit,
          icon: Icons.add_circle,
          label: 'Save Product',
        ),
      ),
    );
  }
}
