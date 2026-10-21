import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Asks before doing something hard to undo. True only when the person
/// confirmed.
///
/// Closes itself through its own [Navigator] and not with `Get.back()`: in
/// GetX 4 `Get.back()` closes a visible snackbar first and returns, so a
/// "Cancelar" tapped while a toast is still up left the dialog open.
Future<bool> confirmAction({
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await Get.dialog<bool>(
    ConfirmDialog(title: title, message: message, confirmLabel: confirmLabel),
  );

  return confirmed == true;
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
