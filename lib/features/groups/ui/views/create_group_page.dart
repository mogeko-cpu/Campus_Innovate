import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../viewmodels/create_group_view_model.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  CreateGroupViewModel get _viewModel => Get.find<CreateGroupViewModel>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final group = await _viewModel.submit(
      name: _nameController.text,
      description: _descriptionController.text,
    );

    if (group == null) {
      Get.snackbar(
        'Error',
        _viewModel.error.value ?? 'No se pudo crear el grupo',
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    Get.back(result: group);
    Get.snackbar(
      'Grupo creado',
      '"${group.name}" ya puede publicar proyectos',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear grupo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Arma tu equipo',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Los proyectos se publican a nombre de un grupo, y sus '
              'integrantes se gestionan desde aquí.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                hintText: 'Ej. Semillero de Robótica',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Escribe un nombre de al menos 3 caracteres';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: '¿En qué trabaja el grupo y a quién busca?',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 15) {
                  return 'Describe el grupo en al menos 15 caracteres';
                }

                return null;
              },
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
                    : const Text('Crear grupo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
