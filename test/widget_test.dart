import 'package:billing_app/core/error/failure.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/repositories/product_repository.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:billing_app/features/product/presentation/bloc/product_bloc.dart';
import 'package:billing_app/features/product/presentation/pages/add_product_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets('Add product page generates an in-app barcode for grocery items',
      (WidgetTester tester) async {
    final repository = _FakeProductRepository();
    final productBloc = ProductBloc(
      getProductsUseCase: GetProductsUseCase(repository),
      addProductUseCase: AddProductUseCase(repository),
      addProductsUseCase: AddProductsUseCase(repository),
      updateProductUseCase: UpdateProductUseCase(repository),
      deleteProductUseCase: DeleteProductUseCase(repository),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: productBloc,
          child: const AddProductPage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Add Grocery Item'), findsOneWidget);
    expect(find.text('Item Name'), findsOneWidget);
    expect(
      find.text(
        'Barcode is created by the app for kirana store items. Tap Create to generate a fresh barcode.',
      ),
      findsOneWidget,
    );
    expect(find.text('Create'), findsOneWidget);

    final barcodeField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(barcodeField.controller, isNotNull);
    expect(barcodeField.controller!.text, matches(RegExp(r'^\d{13}$')));
  });
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> addProducts(List<Product> products) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    return const Left(CacheFailure('Not needed in this test'));
  }

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    return const Right(null);
  }
}
