import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../domain/models/listing.dart';
import '../viewmodels/listing_detail_view_model.dart';

class ListingDetailPage extends GetView<ListingDetailViewModel> {
  const ListingDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del proyecto')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final listing = controller.listing.value;

        if (listing == null) {
          return Center(
            child: Text(controller.error.value ?? 'Proyecto no encontrado'),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _Header(listing: listing),
            const SizedBox(height: 24),
            _Section(
              title: 'Sobre el proyecto',
              child: Text(
                listing.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (listing.requiredSkills.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Section(
                title: 'Habilidades buscadas',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in listing.requiredSkills)
                      Chip(label: Text(skill)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _Section(
              title: 'Equipo',
              child: Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${listing.memberIds.length} de ${listing.maxMembers} integrantes',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _JoinAction(controller: controller, listing: listing),
          ],
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  final Listing listing;

  const _Header({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            listing.category,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          listing.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.secondaryContainer,
              child: Text(
                listing.creatorName.characters.first,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.creatorName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Creador del proyecto',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _JoinAction extends StatelessWidget {
  final ListingDetailViewModel controller;
  final Listing listing;

  const _JoinAction({required this.controller, required this.listing});

  @override
  Widget build(BuildContext context) {
    if (controller.isCreator) {
      return const _Notice(
        icon: Icons.verified_outlined,
        text: 'Este es tu proyecto.',
      );
    }

    if (controller.isMember) {
      return const _Notice(
        icon: Icons.check_circle_outline,
        text: 'Ya formas parte de este equipo.',
      );
    }

    final request = controller.myRequest.value;

    if (request != null) {
      return _Notice(
        icon: Icons.schedule,
        text: 'Solicitud enviada — estado: ${request.status.label}.',
      );
    }

    if (listing.isFull) {
      return const _Notice(
        icon: Icons.group_off_outlined,
        text: 'El equipo ya está completo.',
      );
    }

    return FilledButton.icon(
      onPressed: () async {
        await Get.toNamed(AppRoutes.joinOf(listing.id));
        await controller.load();
      },
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Solicitar unirme'),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
