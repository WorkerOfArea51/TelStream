import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_picker/country_picker.dart' as cp;
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // Telegram-style country select state
  String _selectedCountryName = 'United States';
  String _selectedCountryCode = 'US';
  String _selectedCountryFlag = '🇺🇸';
  cp.Country? _currentCountry;

  @override
  void initState() {
    super.initState();
    // Default prefix matching +1 for US
    _phoneController.text = '+1 ';
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;

    // Force text to start with '+'
    if (text.isNotEmpty && !text.startsWith('+')) {
      _phoneController.removeListener(_onPhoneChanged);
      _phoneController.text = '+$text';
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
      _phoneController.addListener(_onPhoneChanged);
      return;
    }

    // Dynamic country prefix matching
    final cp.CountryService countryService = cp.CountryService();
    final allCountries = countryService.getAll();

    // Sort by phoneCode length descending so we match +1242 before +1
    final sortedCountries = List<cp.Country>.from(allCountries)
      ..sort((a, b) => b.phoneCode.length.compareTo(a.phoneCode.length));

    cp.Country? matchedCountry;
    final cleaned = text.replaceAll(RegExp(r'[^\d+]'), ''); // Keep digits and + only

    for (final country in sortedCountries) {
      final dialCode = '+${country.phoneCode}';
      if (cleaned.startsWith(dialCode)) {
        matchedCountry = country;
        break;
      }
    }

    if (matchedCountry != null) {
      final country = matchedCountry;
      if (country != _currentCountry) {
        setState(() {
          _currentCountry = country;
          _selectedCountryName = country.name;
          _selectedCountryCode = country.countryCode;
          _selectedCountryFlag = country.flagEmoji;
        });
      }
    } else {
      if (_currentCountry != null) {
        setState(() {
          _currentCountry = null;
          _selectedCountryName = 'Select Country';
          _selectedCountryCode = '';
          _selectedCountryFlag = '';
        });
      }
    }
  }

  void _openCountryPicker(BuildContext context) {
    cp.showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (cp.Country country) {
        setState(() {
          _selectedCountryName = country.name;
          _selectedCountryCode = country.countryCode;
          _selectedCountryFlag = country.flagEmoji;
          _currentCountry = country;

          // Replace phone number prefix with chosen country code
          _phoneController.text = '+${country.phoneCode} ';
          _phoneController.selection = TextSelection.fromPosition(
            TextPosition(offset: _phoneController.text.length),
          );
        });
      },
      countryListTheme: cp.CountryListThemeData(
        backgroundColor: const Color(0xFF0F172A), // Slate 900 dark list
        textStyle: const TextStyle(color: Colors.white, fontSize: 16),
        searchTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search Country',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    final showAppBar = authState.step == AuthStep.waitingForCode || authState.step == AuthStep.waitingForPassword;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Premium deep dark background
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  authController.resetAuth();
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildForm(authState, authController),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState state, AuthController controller) {
    switch (state.step) {
      case AuthStep.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        );
      case AuthStep.waitingForNumber:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.stream, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                'Your phone number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please confirm your country code and enter your phone number.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Country Selector
              GestureDetector(
                onTap: () => _openCountryPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountryCode.isNotEmpty
                            ? '$_selectedCountryFlag   $_selectedCountryName'
                            : 'Select Country',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white30,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Phone number input field
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onSubmitted: (val) {
                  final phoneText = val.trim();
                  if (phoneText.isNotEmpty) {
                    controller.setPhoneNumber(phoneText);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: () {
                    final phoneText = _phoneController.text.trim();
                    if (phoneText.isNotEmpty) {
                      controller.setPhoneNumber(phoneText);
                    }
                  },
                  backgroundColor: Colors.blueAccent,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      case AuthStep.waitingForCode:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.sms_rounded, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                'Enter code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We have sent an SMS with an activation code to your phone number.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onSubmitted: (val) {
                  final code = val.trim();
                  if (code.isNotEmpty) {
                    controller.checkCode(code);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Code',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'Enter activation code',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: () {
                    final code = _codeController.text.trim();
                    if (code.isNotEmpty) {
                      controller.checkCode(code);
                    }
                  },
                  backgroundColor: Colors.blueAccent,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      case AuthStep.waitingForPassword:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.lock_rounded, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                '2FA Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account is protected by a two-step verification password.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onSubmitted: (val) {
                  final pwd = val.trim();
                  if (pwd.isNotEmpty) {
                    controller.checkPassword(pwd);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'Enter 2FA password',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: () {
                    final pwd = _passwordController.text.trim();
                    if (pwd.isNotEmpty) {
                      controller.checkPassword(pwd);
                    }
                  },
                  backgroundColor: Colors.blueAccent,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      case AuthStep.authenticated:
        return const Center(
          child: Text('Authenticated!', style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
        );
      case AuthStep.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('An error occurred.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      controller.initializeTdlib();
                    },
                    child: const Text('Retry Initialization', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
