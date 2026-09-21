import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../viewmodels/authentication_controller.dart';

/// "Continuar con Google", with the separator that keeps it off the form.
///
/// One widget for both screens because both offer exactly the same thing: ROBLE
/// receives Google's answer and, since Google states whether the address is
/// verified, links the login to the account that already has that e-mail or
/// creates it. Signing in and registering are the same act here, so a second
/// copy of the button would only be two labels drifting apart.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  AuthenticationController get _controller =>
      Get.find<AuthenticationController>();

  Future<void> _start() async {
    final started = await _controller.signInWithGoogle();

    // Nothing left to do on the web when it went well: the page is already on
    // its way to Google and the session shows up when the browser comes back.
    if (started) return;

    Get.snackbar(
      'No se pudo continuar con Google',
      _controller.error.value,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        Obx(
          () => OutlinedButton.icon(
            onPressed: _controller.isLoading ? null : _start,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const _GoogleMark(),
            label: const Text('Continuar con Google'),
          ),
        ),
      ],
    );
  }
}

/// Google's "G", drawn instead of shipped.
///
/// Two reasons not to bring the real logo: it is a brand-licensed asset that
/// would have to be kept, and an image without a size inside `icon:` stretches
/// to the bitmap's natural size and breaks the button's row.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
