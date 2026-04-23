import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

class PaymentQrPage extends StatefulWidget {
  const PaymentQrPage({super.key});

  @override
  State<PaymentQrPage> createState() => _PaymentQrPageState();
}

class _PaymentQrPageState extends State<PaymentQrPage> {
  final _amountController = TextEditingController();
  double _amount = 0;
  bool _isPrinting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Payment QR'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<ShopBloc, ShopState>(
          builder: (context, shopState) {
            final shopLoaded = shopState is ShopLoaded;
            final shopName = shopLoaded ? shopState.shop.name : 'Shop';
            final upiId = shopLoaded ? shopState.shop.upiId.trim() : '';
            final qrData = upiId.isEmpty || _amount <= 0
                ? ''
                : _buildUpiPaymentUri(
                    upiId: upiId,
                    shopName: shopName,
                    amount: _amount,
                  );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Payment QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          upiId.isEmpty
                              ? 'Add UPI ID in Shop Details to use this feature.'
                              : 'Enter amount, show QR, and print it separately from billing.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E8E1)),
                    ),
                    child: TextField(
                      controller: _amountController,
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
                        hintText: 'Enter payment amount',
                        prefixText: '₹ ',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _amount = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4E8E1)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          shopName.trim().isEmpty ? 'Shop' : shopName.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _amount <= 0
                              ? 'Enter amount to generate QR'
                              : '₹ ${_amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: _amount <= 0 ? 14 : 28,
                            fontWeight: FontWeight.w900,
                            color: _amount <= 0
                                ? AppTheme.mutedTextColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 230,
                          height: 230,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE4E8E1)),
                          ),
                          child: qrData.isEmpty
                              ? const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 96,
                                  color: Color(0xFFD5DDD8),
                                )
                              : PrettyQrView.data(data: qrData),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          upiId.isEmpty ? 'No UPI ID found' : 'UPI: $upiId',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.mutedTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    onPressed: upiId.isEmpty || _amount <= 0 || _isPrinting
                        ? null
                        : () =>
                            _printPaymentQr(shopName: shopName, upiId: upiId),
                    label: 'Print Payment QR',
                    icon: Icons.print_rounded,
                    isLoading: _isPrinting,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _printPaymentQr({
    required String shopName,
    required String upiId,
  }) async {
    setState(() => _isPrinting = true);

    try {
      final printerHelper = PrinterHelper();
      final hasActiveConnection = await printerHelper.connectionStatus();
      if (!hasActiveConnection) {
        final savedMac = HiveDatabase.settingsBox.get('printer_mac');
        if (savedMac == null) {
          throw Exception('Printer not connected & no saved printer found!');
        }

        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          throw Exception('Failed to auto-connect to printer!');
        }
      }

      await printerHelper.printPaymentQr(
        shopName: shopName,
        upiId: upiId,
        amount: _amount,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment QR printed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
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
}
