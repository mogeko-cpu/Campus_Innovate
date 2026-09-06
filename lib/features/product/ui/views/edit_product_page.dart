import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loggy/loggy.dart';

import '../../domain/models/product.dart';
import '../viewmodels/product_controller.dart';

class EditProductPage extends StatefulWidget {
  const EditProductPage({super.key});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> with UiLoggy {
  Product product = Get.arguments[0];
  final controllerProductName = TextEditingController();
  final controllerProductDesc = TextEditingController();
  final controllerProductQuantity = TextEditingController();

  @override
  Widget build(BuildContext context) {
    ProductController productController = Get.find();
    controllerProductName.text = product.name;
    controllerProductDesc.text = product.description;
    controllerProductQuantity.text = product.quantity.toString();
    loggy.debug('Update page product $product');
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: controllerProductName,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controllerProductDesc,
              decoration: const InputDecoration(
                labelText: 'Product Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controllerProductQuantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      product.name = controllerProductName.text;
                      product.description = controllerProductDesc.text;
                      product.quantity =
                          int.tryParse(controllerProductQuantity.text) ?? 0;
                      try {
                        await productController.updateProduct(product);
                        Get.back();
                      } catch (err) {
                        Get.snackbar(
                          "Error",
                          err.toString(),
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                    child: const Text("Update"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
