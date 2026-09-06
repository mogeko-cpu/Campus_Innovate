import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loggy/loggy.dart';

import '../../../auth/ui/viewmodels/authentication_controller.dart';
import '../../domain/models/product.dart';

import '../viewmodels/product_controller.dart';
import 'edit_product_page.dart';
import 'add_product_page.dart';

class ListProductPage extends StatefulWidget {
  const ListProductPage({super.key});

  @override
  State<ListProductPage> createState() => _ListProductPageState();
}

class _ListProductPageState extends State<ListProductPage> with UiLoggy {
  ProductController userController = Get.find();
  AuthenticationController authenticationController = Get.find();

  Future<void> _logout() async {
    final loggedOut = await authenticationController.logOut();
    if (!loggedOut) {
      Get.snackbar(
        'Logout',
        authenticationController.error.value,
        icon: const Icon(Icons.error, color: Colors.red),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text('Welcome, ${authenticationController.loggedEmail}'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              _logout();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              userController.deleteProducts();
            },
          ),
        ],
      ),
      body: Center(child: _getXlistView()),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          loggy.debug('Add product from UI');
          Get.to(() => const AddProductPage());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getXlistView() {
    return Obx(
      () => userController.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await userController.getProducts();
              },
              child: ListView.builder(
                itemCount: userController.products.length,
                itemBuilder: (context, index) {
                  Product user = userController.products[index];
                  return Dismissible(
                    key: UniqueKey(),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Text(
                          "Deleting",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    onDismissed: (direction) {
                      userController.deleteProduct(user);
                    },
                    child: Card(
                      child: ListTile(
                        title: Text(user.name),
                        subtitle: Text(user.description),
                        trailing: Text(user.quantity.toString()),
                        onTap: () {
                          Get.to(
                            () => const EditProductPage(),
                            arguments: [user, user.id],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
