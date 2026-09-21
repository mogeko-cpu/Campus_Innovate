import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/roble/roble_password_policy.dart';
import '../../../../routes/app_routes.dart';
import '../viewmodels/authentication_controller.dart';
import '../widgets/google_sign_in_button.dart';

/// Account registration.
///
/// Asks for a name, which the previous version did not: the name travels with
/// every project and every application, so leaving it as the e-mail would put
/// people's addresses on screens the whole campus reads.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthenticationController get _controller =>
      Get.find<AuthenticationController>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final created = await _controller.signUp(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );

    if (!created) {
      Get.snackbar(
        'No se pudo registrar',
        _controller.error.value,
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    // `signup-direct` leaves the account usable immediately, so the first login
    // is the next screen and not an e-mail with a code.
    await Get.offAllNamed(AppRoutes.login);
    Get.snackbar(
      'Cuenta creada',
      'Ya puedes iniciar sesión con tu correo.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Text(
              'Tus datos',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu nombre aparecerá en los proyectos que publiques.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                hintText: 'Ej. Mariana Ospina',
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 3) {
                  return 'Escribe tu nombre completo';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Correo institucional',
                hintText: 'nombre@uninorte.edu.co',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) return 'Escribe tu correo';
                if (!email.contains('@')) return 'Escribe un correo válido';

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText:
                    'Mínimo ${RoblePasswordPolicy.minLength} caracteres, con '
                    'mayúscula, minúscula, número y un símbolo '
                    '(${RoblePasswordPolicy.symbols})',
                helperMaxLines: 3,
              ),
              onFieldSubmitted: (_) => _submit(),
              // The same rules the source checks: the form is where a rejection
              // costs nothing, while a rejected request spends one of the five
              // registrations ROBLE allows per hour on this network.
              validator: (value) => RoblePasswordPolicy.validate(value ?? ''),
            ),
            const SizedBox(height: 28),
            Obx(
              () => FilledButton(
                onPressed: _controller.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _controller.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear cuenta'),
              ),
            ),
            // Same button as the login screen: with Google there is no account to
            // create separately, so the form above is only for whoever wants a
            // password.
            const GoogleSignInButton(),
          ],
        ),
      ),
    );
  }
}
