import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/auth/shop_access_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          context.read<BillingBloc>().add(ClearCartEvent());
          context.go('/');
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Checkout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left,
                  size: 28, color: Theme.of(context).primaryColor),
              onPressed: () {
                context.read<BillingBloc>().add(ClearCartEvent());
                context.go('/');
              },
            ),
          ),
          body: SafeArea(
            top: false,
            child: BlocConsumer<BillingBloc, BillingState>(
              listener: (context, state) {
                if (state.printSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Printed successfully'),
                      backgroundColor: Colors.green));
                } else if (state.saleRecorded && state.saleId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Bill saved as ${state.saleId}'),
                      backgroundColor: Colors.green));
                }
              },
              builder: (context, billingState) {
                return BlocBuilder<ShopBloc, ShopState>(
                    builder: (context, shopState) {
                  String upiId = '';
                  String shopName = 'Shop';

                  if (shopState is ShopLoaded) {
                    upiId = shopState.shop.upiId;
                    shopName = shopState.shop.name;
                  }

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        // Table
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Table(
                              border: const TableBorder(
                                horizontalInside:
                                    BorderSide(color: borderColor),
                                bottom: BorderSide(color: borderColor),
                              ),
                              children: [
                                // Header row
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    border: Border(
                                        bottom: BorderSide(color: borderColor)),
                                  ),
                                  children: [
                                    _buildHeaderCell(
                                        'Product Name', TextAlign.left),
                                    _buildHeaderCell('Price', TextAlign.right),
                                    _buildHeaderCell('Total', TextAlign.right),
                                  ],
                                ),
                                // Items rows
                                ...billingState.cartItems.map((item) {
                                  return TableRow(
                                    children: [
                                      _buildDataCell(
                                        '${QuantityFormatter.format(item.quantity)} x ${item.product.name}',
                                        TextAlign.left,
                                      ),
                                      _buildDataCell(
                                          '₹${item.product.price.toStringAsFixed(2)}',
                                          TextAlign.right,
                                          isSubtitle: true),
                                      _buildDataCell(
                                          '₹${item.total.toStringAsFixed(2)}',
                                          TextAlign.right,
                                          isBold: true),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        if (billingState.selectedCustomer != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE5E5EA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(billingState.selectedCustomer!['name']
                                        ?.toString() ??
                                    ''),
                                Text(billingState.selectedCustomer!['mobile']
                                        ?.toString() ??
                                    ''),
                                if ((billingState.selectedCustomer!['address']
                                            ?.toString() ??
                                        '')
                                    .isNotEmpty)
                                  Text(billingState.selectedCustomer!['address']
                                      .toString()),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Discount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Enter discount amount',
                                  prefixText: '₹ ',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  final discount = double.tryParse(value) ?? 0;
                                  context
                                      .read<BillingBloc>()
                                      .add(UpdateDiscountEvent(discount));
                                },
                              ),
                              if (billingState.discountAmount >
                                  billingState.subtotalAmount) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Discount is capped at the bill subtotal.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mode of Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _buildPaymentModeChip(
                                    context,
                                    label: 'Offline',
                                    icon: Icons.payments_outlined,
                                    isSelected:
                                        billingState.paymentMode == 'Offline',
                                  ),
                                  _buildPaymentModeChip(
                                    context,
                                    label: 'Online',
                                    icon: Icons.qr_code_2_outlined,
                                    isSelected:
                                        billingState.paymentMode == 'Online',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildBottomBar(
                          context,
                          billingState: billingState,
                          shopState: shopState,
                          upiId: upiId,
                          shopName: shopName,
                        ),
                      ],
                    ),
                  );
                });
              },
            ),
          ),
        ));
  }

  Widget _buildBottomBar(
    BuildContext context, {
    required BillingState billingState,
    required ShopState shopState,
    required String upiId,
    required String shopName,
  }) {
    final accessProfile = ShopAccessController.instance.profile;
    final resolvedShopName =
        shopName.trim().isNotEmpty ? shopName.trim() : accessProfile?.shopName;
    final resolvedShopMobile = accessProfile?.mobileNumber ?? '';

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(24),
            right: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  if (upiId.isNotEmpty) ...[
                    const Text(
                      'Scan to Pay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: PrettyQrView.data(
                        data: _buildUpiPaymentUri(
                          upiId: upiId,
                          shopName: resolvedShopName ?? 'Shop',
                          amount: billingState.totalAmount,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  if (billingState.effectiveDiscountAmount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₹${billingState.subtotalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '- ₹${billingState.effectiveDiscountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GRAND TOTAL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '₹${billingState.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    onPressed: () {
                      if (shopState is ShopLoaded) {
                        final shop = shopState.shop;
                        context.read<BillingBloc>().add(SaveBillEvent(
                            shopName: _firstNonEmpty(
                              shop.name,
                              resolvedShopName,
                              'Shop',
                            ),
                            address1: shop.addressLine1,
                            address2: shop.addressLine2,
                            phone: _firstNonEmpty(
                              shop.phoneNumber,
                              resolvedShopMobile,
                            ),
                            upiId: shop.upiId,
                            footer: shop.footerText,
                            paymentMode: billingState.paymentMode,
                            customer: billingState.selectedCustomer));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shop details not loaded'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    label:
                        billingState.saleRecorded ? 'Bill Saved' : 'Save Bill',
                    icon: billingState.saleRecorded
                        ? Icons.check_circle
                        : Icons.save,
                    isLoading: billingState.isSaving,
                  ),
                ),
                Expanded(
                  child: PrimaryButton(
                    onPressed: () {
                      if (shopState is ShopLoaded) {
                        final shop = shopState.shop;
                        context.read<BillingBloc>().add(PrintReceiptEvent(
                            shopName: _firstNonEmpty(
                              shop.name,
                              resolvedShopName,
                              'Shop',
                            ),
                            address1: shop.addressLine1,
                            address2: shop.addressLine2,
                            phone: _firstNonEmpty(
                              shop.phoneNumber,
                              resolvedShopMobile,
                            ),
                            upiId: shop.upiId,
                            footer: shop.footerText,
                            paymentMode: billingState.paymentMode,
                            customer: billingState.selectedCustomer));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shop details not loaded'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    label: 'Print Bill',
                    icon: Icons.print,
                    isLoading: billingState.isPrinting,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _firstNonEmpty(String? first, [String? second, String? third]) {
    for (final value in [first, second, third]) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String _buildUpiPaymentUri({
    required String upiId,
    required String shopName,
    required double amount,
  }) {
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: <String, String>{
        'pa': upiId.trim(),
        'pn': shopName.trim().isEmpty ? 'Shop' : shopName.trim(),
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
      },
    ).toString();
  }

  Widget _buildPaymentModeChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          context.read<BillingBloc>().add(UpdatePaymentModeEvent(label)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.10)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }
}
