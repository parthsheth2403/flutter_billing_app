part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final bool saleRecorded;
  final bool isSaving;
  final String? saleId;
  final Map<String, dynamic>? selectedCustomer;
  final String paymentMode;
  final double discountAmount;
  final bool gstEnabled;
  final double gstRate;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.saleRecorded = false,
    this.isSaving = false,
    this.saleId,
    this.selectedCustomer,
    this.paymentMode = 'Offline',
    this.discountAmount = 0,
    this.gstEnabled = false,
    this.gstRate = 18,
  });

  double get subtotalAmount =>
      cartItems.fold(0, (sum, item) => sum + item.total);

  double get effectiveDiscountAmount {
    if (discountAmount <= 0) return 0;
    if (discountAmount > subtotalAmount) return subtotalAmount;
    return discountAmount;
  }

  double get taxableAmount => subtotalAmount - effectiveDiscountAmount;

  double get gstAmount {
    if (!gstEnabled || gstRate <= 0) return 0;
    final baseAmount = taxableAmount;
    if (baseAmount <= 0) return 0;
    return (baseAmount * gstRate) / 100;
  }

  double get totalAmount => taxableAmount + gstAmount;

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    bool? saleRecorded,
    bool? isSaving,
    String? saleId,
    Map<String, dynamic>? selectedCustomer,
    bool clearCustomer = false,
    String? paymentMode,
    double? discountAmount,
    bool? gstEnabled,
    double? gstRate,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      saleRecorded: saleRecorded ?? this.saleRecorded,
      isSaving: isSaving ?? this.isSaving,
      saleId: saleId ?? this.saleId,
      selectedCustomer:
          clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      paymentMode: paymentMode ?? this.paymentMode,
      discountAmount: discountAmount ?? this.discountAmount,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      gstRate: gstRate ?? this.gstRate,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        isPrinting,
        printSuccess,
        saleRecorded,
        isSaving,
        saleId,
        selectedCustomer,
        paymentMode,
        discountAmount,
        gstEnabled,
        gstRate,
      ];
}
