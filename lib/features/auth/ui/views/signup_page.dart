import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loggy/loggy.dart';
import '../viewmodels/authentication_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with UiLoggy {
  final controllerEmail = TextEditingController(text: 'a@a.com');
  final controllerPassword = TextEditingController(text: 'ThePassword1!');
  final controllerValidation = TextEditingController();
  AuthenticationController authenticationController = Get.find();

  Future<void> _signup(String theEmail, String thePassword) async {
    final created = await authenticationController.signUp(
      theEmail,
      thePassword,
    );

    if (created) {
      Get.snackbar(
        "Sign Up",
        'User created successfully',
        icon: const Icon(Icons.person, color: Colors.red),
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        "Sign Up",
        authenticationController.error.value,
        icon: const Icon(Icons.person, color: Colors.red),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up"), centerTitle: true),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: registerPhaseWidget(context, GlobalKey<FormState>()),
        ),
      ),
    );
  }

  Form registerPhaseWidget(BuildContext context, GlobalKey<FormState> key) {
    return Form(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Sign Up Information", style: TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            controller: controllerEmail,
            decoration: const InputDecoration(
              labelText: "Email address",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                loggy.debug('SignUp validation empty email');
                return "Enter email";
              } else if (!value.contains('@')) {
                loggy.debug('SignUp validation invalid email');
                return "Enter valid email address";
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: controllerPassword,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            validator: (value) {
              if (value!.isEmpty) {
                return "Enter password";
              } else if (value.length < 6) {
                return "Password should have at least 6 characters";
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    final form = key.currentState;
                    form!.save();
                    FocusScope.of(context).requestFocus(FocusNode());
                    if (key.currentState!.validate()) {
                      loggy.debug('SignUp validation form ok');
                      await _signup(
                        controllerEmail.text,
                        controllerPassword.text,
                      );
                    } else {
                      loggy.debug('SignUp validation form invalid');
                    }
                  },
                  child: const Text("Submit"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
