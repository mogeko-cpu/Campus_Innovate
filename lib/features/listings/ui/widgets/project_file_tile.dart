import 'package:flutter/material.dart';

import '../../../../core/time_ago.dart';
import '../../../shell/ui/widgets/panel.dart';
import '../../domain/models/project_file.dart';

/// One shared file or link: what it is, who shared it and when.
///
/// The square on the left takes the color of the kind of file, the way a file
/// browser does, so a PDF and a spreadsheet are told apart before reading.
class ProjectFileTile extends StatelessWidget {
  final ProjectFile file;
  final bool canDelete;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const ProjectFileTile({
    super.key,
    required this.file,
    required this.canDelete,
    required this.isBusy,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = _styleOf(file, colors);
    final kind = file.isLink ? 'Enlace' : readableSize(file.sizeBytes);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: Panel.decorationOf(context, radius: 16),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(style.icon, color: style.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$kind · ${file.uploaderName} · '
                          '${timeAgo(file.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'Eliminar archivo',
                      onPressed: isBusy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        file.isLink ? Icons.open_in_new : Icons.download_outlined,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static ({IconData icon, Color color}) _styleOf(
    ProjectFile file,
    ColorScheme colors,
  ) {
    if (file.isLink) return (icon: Icons.link, color: colors.primary);

    return switch (file.extension) {
      'pdf' => (
          icon: Icons.picture_as_pdf_outlined,
          color: const Color(0xFFD1447A),
        ),
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'svg' => (
          icon: Icons.image_outlined,
          color: const Color(0xFF1B8B9E),
        ),
      'doc' || 'docx' || 'odt' || 'txt' || 'md' => (
          icon: Icons.description_outlined,
          color: const Color(0xFF2F6FED),
        ),
      'xls' || 'xlsx' || 'csv' => (
          icon: Icons.table_chart_outlined,
          color: const Color(0xFF1E9E6B),
        ),
      'ppt' || 'pptx' => (
          icon: Icons.slideshow_outlined,
          color: const Color(0xFFE07A1E),
        ),
      'zip' || 'rar' || '7z' => (
          icon: Icons.folder_zip_outlined,
          color: const Color(0xFFB0793F),
        ),
      'mp4' => (icon: Icons.movie_outlined, color: const Color(0xFF7A4FE0)),
      'mp3' => (icon: Icons.audiotrack_outlined, color: const Color(0xFF7A4FE0)),
      _ => (icon: Icons.insert_drive_file_outlined, color: colors.secondary),
    };
  }
}
