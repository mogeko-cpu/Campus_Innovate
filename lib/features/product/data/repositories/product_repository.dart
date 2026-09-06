import '../../domain/repositories/i_product_repository.dart';
import '../datasources/i_remote_product_source.dart';
import '../../domain/models/product.dart';

class ProductRepository implements IProductRepository {
  late IProductSource userSource;

  ProductRepository(this.userSource);

  @override
  Future<List<Product>> getProducts() async => await userSource.getProducts();

  @override
  Future<bool> addProduct(Product user) async =>
      await userSource.addProduct(user);

  @override
  Future<bool> updateProduct(Product user) async =>
      await userSource.updateProduct(user);

  @override
  Future<bool> deleteProduct(Product user) async =>
      await userSource.deleteProduct(user);

  @override
  Future<bool> deleteProducts() async => await userSource.deleteProducts();
}
