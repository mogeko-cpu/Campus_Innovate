import 'package:loggy/loggy.dart';
import '../../domain/models/product.dart';
import 'package:http/http.dart' as http;

import 'i_remote_product_source.dart';

class RemoteProductSource with UiLoggy implements IProductSource {
  final http.Client httpClient;

  RemoteProductSource(this.httpClient);

  @override
  Future<List<Product>> getProducts() async {
    List<Product> products = [];

    return Future.value(products);
  }

  @override
  Future<bool> addProduct(Product product) async {
    loggy.debug("Web service, Adding product $product");
    return Future.value(true);
  }

  @override
  Future<bool> updateProduct(Product product) async {
    loggy.debug("Web service, Updating product with id $product");
    return Future.value(true);
  }

  @override
  Future<bool> deleteProduct(Product product) async {
    loggy.debug("Web service, Deleting product with id $product");
    return Future.value(true);
  }

  @override
  Future<bool> deleteProducts() async {
    List<Product> products = await getProducts();
    for (var product in products) {
      await deleteProduct(product);
    }
    return Future.value(true);
  }
}
