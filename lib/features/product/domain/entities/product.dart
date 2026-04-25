import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final String brand;
  final int stock;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.brand = '',
    this.stock = 0,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    String? brand,
    int? stock,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      brand: brand ?? this.brand,
      stock: stock ?? this.stock,
    );
  }

  @override
  List<Object?> get props => [id, name, barcode, price, brand, stock];
}
