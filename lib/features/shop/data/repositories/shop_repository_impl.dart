import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';
import '../models/shop_model.dart';

class ShopRepositoryImpl implements ShopRepository {
  static const String shopKey = 'shop_details';
  static const Shop _legacyDefaultShop = Shop(
    name: 'Dinesh Shop',
    addressLine1: 'Samrajpet, Mecheri',
    addressLine2: 'Salem - 636453',
    phoneNumber: '+917010674588',
    upiId: 'dineshsowndar@oksbi',
    footerText: 'Thank you, Visit again!!!',
  );

  static const Shop _defaultShop = Shop(
    name: 'Manibhadra Trading Company',
    addressLine1: '',
    addressLine2: '',
    phoneNumber: '',
    upiId: '',
    footerText: 'Thank you. Visit again!',
  );

  @override
  Future<Either<Failure, Shop>> getShop() async {
    try {
      final box = HiveDatabase.shopBox;
      final shop = box.get(shopKey);
      if (shop != null) {
        if (shop == _legacyDefaultShop) {
          final model = ShopModel.fromEntity(_defaultShop);
          await box.put(shopKey, model);
          return const Right(_defaultShop);
        }
        return Right(shop);
      } else {
        return const Right(_defaultShop);
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateShop(Shop shop) async {
    try {
      final box = HiveDatabase.shopBox;
      final model = ShopModel.fromEntity(shop);
      await box.put(shopKey, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
