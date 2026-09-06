import 'package:get/get.dart';

import 'data/datasources/i_remote_product_source.dart';
import 'data/datasources/local/local_product_source.dart';
import 'data/repositories/product_repository.dart';
import 'domain/repositories/i_product_repository.dart';
import 'ui/viewmodels/product_controller.dart';

/// Registers the product dependency chain with GetX.
///
/// Swap [LocalProductSource] for a remote [IProductSource] implementation here
/// when an API is connected; consumers do not need to change.
void registerProduct() {
  Get.put<IProductSource>(LocalProductSource(Get.find()));
  Get.put<IProductRepository>(ProductRepository(Get.find()));
  Get.lazyPut(() => ProductController(Get.find()));
}
