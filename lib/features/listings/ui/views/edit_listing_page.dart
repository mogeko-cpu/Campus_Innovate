import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/info_banner.dart';
import '../../data/repositories/listing_repository.dart';
import '../../domain/models/listing_category.dart';
import '../../domain/models/listing_status.dart';
import '../viewmodels/edit_listing_view_model.dart';
import '../widgets/category_choice_chip.dart';
import '../widgets/status_chip.dart';

/// The leader's form to correct a project and move it through its states.
class EditListingPage extends StatefulWidget {
  const EditListingPage({super.key});

  @override
  State<EditListingPage> createState() => _EditListingPageState();
}

class _EditListingPageState extends State<EditListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skillController = TextEditingController();

  /// The text fields are filled once, when the project arrives, and never
  /// again: a later rebuild must not throw away what the person is typing.
  bool _filled = false;

  EditListingViewModel get _viewModel => Get.find<EditListingViewModel>();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _fillOnce() {
    final listing = _viewModel.listing.value;
    if (_filled || listing == null) return;

    _titleController.text = listing.title;
    _descriptionController.text = listing.description;
    _filled = true;
  }

  void _addSkill() {
    _viewModel.addSkill(_skillController.text);
    _skillController.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final saved = await _viewModel.submit(
      title: _titleController.text,
      description: _descriptionController.text,
    );

    if (!mounted) return;

    if (saved == null) {
      Get.snackbar(
        'No se pudo guardar',
        _viewModel.error.value ?? 'Intenta de nuevo',
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    // The screen's own navigator, not `Get.back()`, which would close a visible
    // snackbar instead of the page.
    Navigator.of(context).pop(saved);
    Get.snackbar(
      'Cambios guardados',
      '"${saved.title}" quedó ${saved.status.label.toLowerCase()}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar proyecto')),
      body: Obx(() {
        if (_viewModel.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final listing = _viewModel.listing.value;

        if (listing == null) {
          return EmptyState.screen(
            icon: Icons.lock_outline,
            title: 'No se puede editar',
            message: _viewModel.error.value ?? 'Proyecto no encontrado',
          );
        }

        _fillOnce();

        final minMembers = _viewModel.minMembers;
        final maxMembers = _viewModel.maxMembers.value;
        final status = _viewModel.status.value;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título del proyecto',
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 5) {
                    return 'Escribe un título de al menos 5 caracteres';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 20) {
                    return 'Describe la idea en al menos 20 caracteres';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              const _Label(text: 'Estado'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in ListingStatus.values)
                    ChoiceChip(
                      avatar: Icon(
                        StatusChip.styleOf(option).icon,
                        size: 16,
                        color: StatusChip.styleOf(option).color,
                      ),
                      label: Text(option.label),
                      selected: status == option,
                      onSelected: (_) => _viewModel.selectStatus(option),
                    ),
                ],
              ),
              if (_viewModel.closesRequests) ...[
                const SizedBox(height: 12),
                InfoBanner(
                  icon: Icons.info_outline,
                  text: 'Al guardar, las solicitudes pendientes se rechazan y '
                      'el proyecto deja de recibir nuevas.',
                  tint: theme.colorScheme.error,
                ),
              ],
              const SizedBox(height: 24),
              const _Label(text: 'Categoría'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in listingCategories)
                    CategoryChoiceChip(
                      category: category,
                      selected: _viewModel.category.value == category,
                      onSelected: () => _viewModel.selectCategory(category),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const _Label(text: 'Tamaño del equipo'),
              // A slider needs room between its ends: with the team already at
              // the largest size there is nothing to choose.
              if (minMembers < ListingRepository.maxTeamSize)
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: maxMembers.toDouble(),
                        min: minMembers.toDouble(),
                        max: ListingRepository.maxTeamSize.toDouble(),
                        divisions: ListingRepository.maxTeamSize - minMembers,
                        label: '$maxMembers',
                        onChanged: (value) =>
                            _viewModel.setMaxMembers(value.round()),
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        '$maxMembers personas',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('$maxMembers personas'),
                ),
              Text(
                'El equipo ya tiene ${listing.memberCount} '
                '${listing.memberCount == 1 ? 'persona' : 'personas'}: '
                'no puede ser más pequeño.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const _Label(text: 'Habilidades que buscas'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addSkill(),
                      decoration: const InputDecoration(
                        hintText: 'Agregar una habilidad',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Agregar habilidad',
                    onPressed: _addSkill,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in _viewModel.requiredSkills)
                    InputChip(
                      label: Text(skill),
                      onDeleted: () => _viewModel.removeSkill(skill),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _viewModel.isSaving.value ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _viewModel.isSaving.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
