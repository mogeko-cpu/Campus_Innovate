import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../viewmodels/authentication_controller.dart';

/// Entry point when there is no session.
///
/// It no longer arrives with credentials typed in: the template shipped with
/// `a@a.com` / `ThePassword1!` in the fields, which against a real database would
/// mean every build trying to log into somebody's account.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthenticationController get _controller =>
      Get.find<AuthenticationController>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final loggedIn = await _controller.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!loggedIn) {
      Get.snackbar(
        'No se pudo entrar',
        _controller.error.value,
        snackPosition: SnackPosition.BOTTOM,
      );

      return;
    }

    // Replaces the stack: going "back" to the login screen from home would make
    // no sense once there is a session.
    await Get.offAllNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            children: [
              Icon(
                Icons.school_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Campus Innovate',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Entra para publicar ideas y unirte a proyectos del campus.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 36),
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
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña'),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Escribe tu contraseña' : null,
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
                      : const Text('Iniciar sesión'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Get.toNamed(AppRoutes.signup),
                child: const Text('Crear una cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
