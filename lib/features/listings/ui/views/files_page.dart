import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/panel.dart';
import '../../domain/models/project_file.dart';
import '../viewmodels/files_view_model.dart';
import '../widgets/link_dialog.dart';
import '../widgets/project_file_tile.dart';

/// The team's shared folder: what each of them uploaded, and the links to what
/// lives elsewhere — the Drive folder, the repository, the Figma board.
class FilesPage extends GetView<FilesViewModel> {
  const FilesPage({super.key});

  void _toast(String title, String message) =>
      Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);

  /// "1 archivo · 2 enlaces", with the right number for each word.
  static String _countLabel(int uploads, int links) =>
      '$uploads ${uploads == 1 ? 'archivo' : 'archivos'} · '
      '$links ${links == 1 ? 'enlace' : 'enlaces'}';

  Future<void> _upload() async {
    final done = await controller.upload();

    // The person closed the chooser: nothing happened, nothing to say.
    if (done == null) return;

    _toast(
      done ? 'Archivo subido' : 'No se pudo subir',
      done
          ? 'El equipo ya lo puede abrir'
          : controller.lastActionError ?? 'Intenta de nuevo',
    );
  }

  Future<void> _addLink() async {
    final form = await Get.dialog<LinkForm>(const LinkDialog());
    if (form == null) return;

    final done = await controller.addLink(name: form.name, url: form.url);

    _toast(
      done ? 'Enlace guardado' : 'No se pudo guardar',
      done
          ? 'El equipo ya lo puede abrir'
          : controller.lastActionError ?? 'Intenta de nuevo',
    );
  }

  Future<void> _open(ProjectFile file) async {
    if (!await controller.open(file)) {
      _toast(
        'No se pudo abrir',
        controller.lastActionError ?? 'Intenta de nuevo',
      );
    }
  }

  Future<void> _delete(ProjectFile file) async {
    final confirmed = await confirmAction(
      title: '¿Eliminar "${file.name}"?',
      message: 'Nadie del equipo lo va a poder abrir de nuevo.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;

    if (!await controller.delete(file)) {
      _toast(
        'No se pudo eliminar',
        controller.lastActionError ?? 'Intenta de nuevo',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final title = controller.listing.value?.title;

          return Text(title == null ? 'Archivos' : 'Archivos · $title');
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null ||
            controller.listing.value == null) {
          return EmptyState.screen(
            icon: Icons.lock_outline,
            title: 'No se pudieron abrir los archivos',
            message: controller.error.value ?? 'Proyecto no encontrado',
          );
        }

        // Read here, inside the `Obx`: the builders below run later, outside
        // it, and would not notice a change.
        final busy = controller.isWorking.value;
        final uploading = controller.uploading.value;
        final files = controller.files.toList();

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Panel(
                title: 'Carpeta del equipo',
                icon: Icons.folder_shared_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _countLabel(controller.uploadCount, controller.linkCount),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Todo lo que suba cualquiera del equipo aparece aquí. '
                      'Hasta 10 MB por archivo; para algo más grande, '
                      'comparte un enlace.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    // One above the other: side by side, the two labels do
                    // not fit a 360 dp phone.
                    FilledButton.icon(
                      onPressed: busy ? null : _upload,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Subir archivo'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _addLink,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Agregar enlace'),
                    ),
                    if (uploading != null) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(minHeight: 6),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Subiendo "$uploading"…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (files.isEmpty)
                const EmptyState.inline(
                  icon: Icons.folder_open_outlined,
                  title: 'Todavía no hay archivos',
                  message: 'Sube documentos o imágenes, o comparte enlaces a '
                      'Drive, GitHub o Figma.',
                )
              else
                for (final file in files)
                  ProjectFileTile(
                    file: file,
                    canDelete: controller.canDelete(file),
                    isBusy: busy,
                    onOpen: () => _open(file),
                    onDelete: () => _delete(file),
                  ),
            ],
          ),
        );
      }),
    );
  }
}
