import '../models/product.dart';

abstract class IProductRepository {
  Future<List<Product>> getProducts();

  Future<bool> addProduct(Product p);

  Future<bool> updateProduct(Product p);

  Future<bool> deleteProduct(Product p);

  Future<bool> deleteProducts();
}
