import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// What the link form hands back.
typedef LinkForm = ({String name, String url});

/// Asks for a link to share: a Drive folder, a repository, a Figma board.
///
/// A widget of its own for the same reason as `TaskDialog`: the controllers have
/// to outlive the closing animation.
class LinkDialog extends StatefulWidget {
  const LinkDialog({super.key});

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();

  bool get _isComplete =>
      _name.text.trim().isNotEmpty && _url.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar enlace'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nombre del enlace',
              hintText: 'Ej. Carpeta del informe final',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Enlace',
              hintText: 'https://drive.google.com/…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isComplete
              ? () => Get.back(result: (name: _name.text, url: _url.text))
              : null,
          child: const Text('Guardar enlace'),
        ),
      ],
    );
  }
}
