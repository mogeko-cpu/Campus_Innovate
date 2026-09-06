import 'dart:convert';

import 'package:f_clean_template/core/i_local_preferences.dart';

import '../../../domain/models/product.dart';
import '../i_remote_product_source.dart';

class LocalProductSource implements IProductSource {
  static const _productsKey = 'products';

  LocalProductSource(this.preferences);

  final ILocalPreferences preferences;

  @override
  Future<bool> addProduct(Product product) async {
    final products = await _readProducts();
    product.id = DateTime.now().millisecondsSinceEpoch.toString();
    products.add(product);
    await _saveProducts(products);
    return true;
  }

  @override
  Future<bool> deleteProduct(Product product) async {
    final products = await _readProducts();
    final initialLength = products.length;
    products.removeWhere((item) => item.id == product.id);
    final removed = products.length != initialLength;
    if (removed) await _saveProducts(products);
    return removed;
  }

  @override
  Future<bool> deleteProducts() async {
    await preferences.remove(_productsKey);
    return true;
  }

  @override
  Future<List<Product>> getProducts() => _readProducts();

  @override
  Future<bool> updateProduct(Product product) async {
    final products = await _readProducts();
    final index = products.indexWhere((item) => item.id == product.id);
    if (index != -1) {
      products[index] = product;
      await _saveProducts(products);
      return true;
    }
    return false;
  }

  Future<List<Product>> _readProducts() async {
    final encoded = await preferences.getString(_productsKey);
    if (encoded == null || encoded.isEmpty) return <Product>[];

    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveProducts(List<Product> products) => preferences.setString(
    _productsKey,
    jsonEncode(products.map((product) => product.toJson()).toList()),
  );
}
