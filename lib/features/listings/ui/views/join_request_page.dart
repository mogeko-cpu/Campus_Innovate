import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../viewmodels/join_request_view_model.dart';

class JoinRequestPage extends StatefulWidget {
  const JoinRequestPage({super.key});

  @override
  State<JoinRequestPage> createState() => _JoinRequestPageState();
}

class _JoinRequestPageState extends State<JoinRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _motivationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _availabilityController = TextEditingController();

  JoinRequestViewModel get _viewModel => Get.find<JoinRequestViewModel>();

  @override
  void dispose() {
    _motivationController.dispose();
    _skillsController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final sent = await _viewModel.submit(
      motivation: _motivationController.text,
      skills: _skillsController.text,
      availability: _availabilityController.text,
    );

    if (!sent) {
      Get.snackbar(
        'Error',
        _viewModel.error.value ?? 'No se pudo enviar la solicitud',
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    Get.back();
    Get.snackbar(
      'Solicitud enviada',
      'El creador del proyecto revisará tu postulación',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar unirme')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Preséntate al equipo',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El creador usará esta información para decidir tu postulación.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _motivationController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿Por qué quieres participar?',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 15) {
                  return 'Cuéntanos tu motivación en al menos 15 caracteres';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _skillsController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿Qué habilidades aportas?',
                hintText: 'Ej. Flutter, investigación de usuarios',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Indica al menos una habilidad';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _availabilityController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Disponibilidad semanal',
                hintText: 'Ej. 6 horas, martes y jueves en la tarde',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Indica tu disponibilidad';
                }

                return null;
              },
            ),
            const SizedBox(height: 32),
            Obx(
              () => FilledButton(
                onPressed: _viewModel.isSending.value ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _viewModel.isSending.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar solicitud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
