import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/category_style.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../domain/models/listing_category.dart';
import '../viewmodels/listings_view_model.dart';
import '../widgets/listing_card.dart';

class ListingsPage extends GetView<ListingsViewModel> {
  const ListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar proyectos'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.explore),
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
                return EmptyState.screen(
                  icon: Icons.error_outline,
                  title: 'No se pudieron cargar los proyectos',
                  message: controller.error.value!,
                );
              }

              final listings = controller.listings;

              if (listings.isEmpty) {
                return const EmptyState.screen(
                  icon: Icons.search_off,
                  title: 'Ningún proyecto coincide',
                  message: 'Prueba con otra categoría o con otro término de '
                      'búsqueda.',
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
                      stats: controller.statsOf(listing),
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

/// A category filter, colored like the chip a matching card would show —
/// "Todas" stays neutral since it does not stand for one category.
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
    final isAll = label == 'Todas';
    final style = isAll ? null : CategoryStyle.of(context, label);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: style == null
            ? null
            : Icon(
                style.icon,
                size: 16,
                color: selected ? Colors.white : style.color,
              ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: style?.color,
        labelStyle: style == null || !selected
            ? null
            : const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        side: style == null
            ? null
            : BorderSide(color: style.color.withValues(alpha: selected ? 0 : 0.4)),
      ),
    );
  }
}
