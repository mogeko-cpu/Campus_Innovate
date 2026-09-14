import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../viewmodels/home_view_model.dart';
import '../widgets/action_card.dart';
import '../widgets/listing_card.dart';

class HomePage extends GetView<HomeViewModel> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Campus Innovate',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.person_outline,
            ),
          ),
        ],
      ),

      body: Obx(
        () => RefreshIndicator(
          onRefresh: controller.loadFeaturedListings,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Hola! 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  '¿Qué quieres hacer hoy?',
                  style: TextStyle(
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: ActionCard(
                        icon: Icons.explore_outlined,
                        title: 'Explorar ideas',
                        onTap: () {},
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ActionCard(
                        icon: Icons.add_circle_outline,
                        title: 'Publicar idea',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 35),

                const Text(
                  'Ideas destacadas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                if (controller.isLoading.value)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (controller.featuredListings.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'No hay ideas disponibles.',
                      ),
                    ),
                  )
                else
                  ...controller.featuredListings.map(
                    (listing) => ListingCard(
                      listing: listing,
                      onTap: () {},
                    ),
                  ),

                const SizedBox(height: 20),

                const Text(
                  'Mi proyecto',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.rocket_launch,
                      ),
                    ),
                    title: const Text(
                      'Mi proyecto actual',
                    ),
                    subtitle: const Text(
                      'Ver espacio de trabajo',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                    ),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            label: 'Proyectos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}