import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../domain/models/listing_category.dart';
import '../viewmodels/listings_view_model.dart';
import '../widgets/listing_card.dart';

class ListingsPage extends GetView<ListingsViewModel> {
  const ListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar proyectos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Get.toNamed(AppRoutes.createListing);
          await controller.load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              onChanged: controller.search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Buscar por título o descripción',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CategoryChip(
                    label: 'Todas',
                    selected: controller.selectedCategory.value == null,
                    onSelected: () => controller.filterByCategory(null),
                  ),
                  for (final category in listingCategories)
                    _CategoryChip(
                      label: category,
                      selected: controller.selectedCategory.value == category,
                      onSelected: () => controller.filterByCategory(category),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.error.value != null) {
                return _Empty(
                  icon: Icons.error_outline,
                  text: controller.error.value!,
                );
              }

              final listings = controller.listings;

              if (listings.isEmpty) {
                return const _Empty(
                  icon: Icons.search_off,
                  text: 'Ningún proyecto coincide con tu búsqueda.',
                );
              }

              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];

                    return ListingCard(
                      listing: listing,
                      onTap: () async {
                        await Get.toNamed(AppRoutes.detailOf(listing.id));
                        await controller.load();
                      },
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: colors.outline),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
