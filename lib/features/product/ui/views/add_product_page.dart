import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../viewmodels/product_controller.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final controllerName = TextEditingController();
  final controllerDesc = TextEditingController();
  final controllerQuantity = TextEditingController();

  @override
  Widget build(BuildContext context) {
    ProductController productController = Get.find();

    return Scaffold(
      appBar: AppBar(title: const Text('New Product')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: controllerName,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controllerDesc,
              decoration: const InputDecoration(
                labelText: 'Product Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controllerQuantity,
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
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      try {
                        await productController.addProduct(
                          controllerName.text,
                          controllerDesc.text,
                          controllerQuantity.text,
                        );
                        Get.back();
                      } catch (err) {
                        Get.snackbar(
                          "Error",
                          err.toString(),
                          icon: const Icon(Icons.error, color: Colors.red),
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                    child: const Text("Save"),
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
