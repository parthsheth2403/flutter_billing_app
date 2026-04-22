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
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

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
      ];
}
