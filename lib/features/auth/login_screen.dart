import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020617), Color(0xFF1E3A8A)], // Dark blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 0,
              color: Colors.black.withValues(alpha: 0.6), // solid, high-legibility M3 container card
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stream, size: 80, color: Colors.blueAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'TelStream',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Stream Telegram Videos Seamlessly',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    if (authState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                    _buildForm(authState, authController),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState state, AuthController controller) {
    switch (state.step) {
      case AuthStep.loading:
        return const CircularProgressIndicator(color: Colors.blueAccent);
      case AuthStep.waitingForNumber:
        return Column(
          children: [
            _buildTextField(
              controller: _phoneController,
              hintText: 'Phone Number (e.g. +1234567890)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildButton('Send Code', () {
              controller.setPhoneNumber(_phoneController.text.trim());
            }),
          ],
        );
      case AuthStep.waitingForCode:
        return Column(
          children: [
            _buildTextField(
              controller: _codeController,
              hintText: 'Login Code',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildButton('Verify Code', () {
              controller.checkCode(_codeController.text.trim());
            }),
          ],
        );
      case AuthStep.waitingForPassword:
        return Column(
          children: [
            _buildTextField(
              controller: _passwordController,
              hintText: '2FA Password',
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildButton('Submit Password', () {
              controller.checkPassword(_passwordController.text.trim());
            }),
          ],
        );
      case AuthStep.authenticated:
        return const Text('Authenticated!', style: TextStyle(color: Colors.greenAccent, fontSize: 18));
      case AuthStep.error:
        return Column(
          children: [
            const Text('An error occurred.', style: TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            _buildButton('Retry Initialization', () {
               controller.initializeTdlib();
            }),
          ],
        );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withOpacity(0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
