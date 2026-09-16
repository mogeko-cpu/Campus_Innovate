import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/models/listing_category.dart';
import '../viewmodels/create_listing_view_model.dart';

class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skillController = TextEditingController();

  CreateListingViewModel get _viewModel => Get.find<CreateListingViewModel>();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _addSkill() {
    _viewModel.addSkill(_skillController.text);
    _skillController.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final listing = await _viewModel.submit(
      title: _titleController.text,
      description: _descriptionController.text,
    );

    if (listing == null) {
      Get.snackbar(
        'Error',
        _viewModel.error.value ?? 'No se pudo crear el proyecto',
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    Get.back(result: listing);
    Get.snackbar(
      'Proyecto publicado',
      '"${listing.title}" ya está visible para el campus',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar idea')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Cuéntanos tu idea',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Entre más claro sea el objetivo, mejores postulantes vas a recibir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título del proyecto',
                hintText: 'Ej. Plataforma de tutorías entre pares',
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
                hintText: '¿Qué problema resuelve y qué esperas lograr?',
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
            _Label(text: 'Categoría'),
            const SizedBox(height: 8),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in listingCategories)
                    ChoiceChip(
                      label: Text(category),
                      selected: _viewModel.category.value == category,
                      onSelected: (_) => _viewModel.selectCategory(category),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Label(text: 'Tamaño del equipo'),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _viewModel.maxMembers.value.toDouble(),
                      min: 2,
                      max: 12,
                      divisions: 10,
                      label: '${_viewModel.maxMembers.value}',
                      onChanged: (value) =>
                          _viewModel.setMaxMembers(value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      '${_viewModel.maxMembers.value} personas',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Label(text: 'Habilidades que buscas'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addSkill(),
                    decoration: const InputDecoration(
                      hintText: 'Ej. Flutter, Diseño UI, Finanzas',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addSkill,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Obx(
              () => Wrap(
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
            ),
            const SizedBox(height: 32),
            Obx(
              () => FilledButton(
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
                    : const Text('Publicar proyecto'),
              ),
            ),
          ],
        ),
      ),
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
