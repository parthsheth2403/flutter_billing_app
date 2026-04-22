import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/feedback_helper.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/quantity_formatter.dart';
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
    on<SelectCustomerEvent>(_onSelectCustomer);
    on<SaveBillEvent>(_onSaveBill);
    on<PrintReceiptEvent>(_onPrintReceipt);
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

  void _onSelectCustomer(
      SelectCustomerEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      selectedCustomer: event.customer,
      clearCustomer: event.customer == null,
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
    if (!state.saleRecorded && state.cartItems.isNotEmpty) {
      final saleId = await SalesStorage.saveSale(
        cartItems: state.cartItems,
        shopName: event.shopName,
        address1: event.address1,
        address2: event.address2,
        phone: event.phone,
        upiId: event.upiId,
        footer: event.footer,
        customer: event.customer,
      );
      emit(state.copyWith(saleRecorded: true, saleId: saleId));
    }

    final printerHelper = PrinterHelper();

    final hasActiveConnection = await printerHelper.connectionStatus();
    if (!hasActiveConnection) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(
              error: 'Failed to auto-connect to printer!', clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(
            error: 'Printer not connected & no saved printer found!',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': QuantityFormatter.format(item.quantity),
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          upiId: event.upiId,
          items: items,
          total: state.totalAmount,
          footer: event.footer);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
