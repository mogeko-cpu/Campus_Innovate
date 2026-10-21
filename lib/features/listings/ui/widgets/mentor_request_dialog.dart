import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/name_avatar.dart';
import '../../../users/domain/models/app_user.dart';

/// What the mentorship form hands back.
typedef MentorRequestForm = ({AppUser mentor, String message});

/// Chooses somebody from the directory and says what the team needs from them.
class MentorRequestDialog extends StatefulWidget {
  /// Everybody who could be asked: people in the directory outside the team.
  final List<AppUser> candidates;

  const MentorRequestDialog({super.key, required this.candidates});

  @override
  State<MentorRequestDialog> createState() => _MentorRequestDialogState();
}

class _MentorRequestDialogState extends State<MentorRequestDialog> {
  final _search = TextEditingController();
  final _message = TextEditingController();
  AppUser? _chosen;

  List<AppUser> get _matches {
    final query = _search.text.trim().toLowerCase();

    final matches = widget.candidates.where(
      (user) =>
          query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query),
    );

    return matches.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  bool get _isComplete =>
      _chosen != null && _message.text.trim().isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _matches;

    return AlertDialog(
      title: const Text('Solicitar mentoría'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o correo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: matches.isEmpty
                    ? Center(
                        child: Text(
                          widget.candidates.isEmpty
                              ? 'Todavía no hay a quién pedírsela: la persona '
                                  'tiene que haber abierto la app al menos una '
                                  'vez.'
                              : 'Nadie coincide con la búsqueda.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final user = matches[index];
                          final selected = _chosen?.id == user.id;

                          return ListTile(
                            dense: true,
                            selected: selected,
                            leading: NameAvatar(name: user.name, radius: 16),
                            title: Text(user.name),
                            subtitle: user.email.isEmpty
                                ? null
                                : Text(user.email),
                            trailing: selected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () => setState(() => _chosen = user),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _message,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  hintText: '¿En qué necesita acompañamiento el equipo?',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isComplete
              ? () => Get.back(
                    result: (mentor: _chosen!, message: _message.text),
                  )
              : null,
          child: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}
