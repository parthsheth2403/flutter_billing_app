import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/billing_settings.dart';
import '../../../../core/utils/feedback_helper.dart';
import '../../../../core/utils/sales_storage.dart';
import '../../domain/entities/cart_item.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<UpdatePaymentModeEvent>(_onUpdatePaymentMode);
    on<UpdateDiscountEvent>(_onUpdateDiscount);
    on<RefreshBillingPreferencesEvent>(_onRefreshBillingPreferences);
    on<SelectCustomerEvent>(_onSelectCustomer);
    on<SaveBillEvent>(_onSaveBill);
    on<PrintReceiptEvent>(_onPrintReceipt);

    add(RefreshBillingPreferencesEvent());
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }

    FeedbackHelper.vibrate();
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  void _onUpdatePaymentMode(
      UpdatePaymentModeEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(paymentMode: event.paymentMode));
  }

  void _onUpdateDiscount(
      UpdateDiscountEvent event, Emitter<BillingState> emit) {
    final safeDiscount =
        event.discountAmount.isFinite && event.discountAmount > 0
            ? event.discountAmount
            : 0.0;
    emit(state.copyWith(discountAmount: safeDiscount));
  }

  void _onSelectCustomer(
      SelectCustomerEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      selectedCustomer: event.customer,
      clearCustomer: event.customer == null,
    ));
  }

  void _onRefreshBillingPreferences(
      RefreshBillingPreferencesEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      gstEnabled: BillingSettings.isGstEnabled,
      gstRate: BillingSettings.gstRate,
    ));
  }

  Future<void> _onSaveBill(
      SaveBillEvent event, Emitter<BillingState> emit) async {
    if (state.saleRecorded || state.cartItems.isEmpty) {
      return;
    }

    emit(state.copyWith(isSaving: true, printSuccess: false, clearError: true));

    try {
      final saleId = await SalesStorage.saveSale(
        cartItems: state.cartItems,
        shopName: event.shopName,
        address1: event.address1,
        address2: event.address2,
        phone: event.phone,
        upiId: event.upiId,
        footer: event.footer,
        paymentMode: event.paymentMode,
        discountAmount: state.effectiveDiscountAmount,
        gstEnabled: state.gstEnabled,
        gstRate: state.gstRate,
        customer: event.customer,
      );

      emit(state.copyWith(
        isSaving: false,
        saleRecorded: true,
        saleId: saleId,
      ));
    } catch (e) {
      emit(state.copyWith(
          isSaving: false,
          error: 'Failed to save bill: $e',
          clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    String? saleId = state.saleId;
    if (!state.saleRecorded && state.cartItems.isNotEmpty) {
      saleId = await SalesStorage.saveSale(
        cartItems: state.cartItems,
        shopName: event.shopName,
        address1: event.address1,
        address2: event.address2,
        phone: event.phone,
        upiId: event.upiId,
        footer: event.footer,
        paymentMode: event.paymentMode,
        discountAmount: state.effectiveDiscountAmount,
        gstEnabled: state.gstEnabled,
        gstRate: state.gstRate,
        customer: event.customer,
      );
      emit(state.copyWith(saleRecorded: true, saleId: saleId));
    }

    final savedSale = saleId == null ? null : HiveDatabase.salesBox.get(saleId);
    if (savedSale == null) {
      emit(state.copyWith(
          error: 'Saved bill not found for printing.', clearError: false));
      emit(state.copyWith(clearError: true));
      return;
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      await SalesStorage.printSavedSale(savedSale);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
