import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleScale;
  late Animation<double> _circleFade;
  late Animation<Offset> _logoOffset;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Fade and scale in the background blue circle
    _circleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _circleScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Jet fly-in offset for the logo from bottom-left (starts far off-screen)
    _logoOffset = Tween<Offset>(
      begin: const Offset(-3.5, 3.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.fastLinearToSlowEaseIn),
      ),
    );

    // Scale up the logo
    _logoScale = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // Rotate the logo like a jet banking (starts rotated to the right/angled, straightens out)
    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.fastOutSlowIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900 dark background
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Center Circle Background
          Center(
            child: FadeTransition(
              opacity: _circleFade,
              child: ScaleTransition(
                scale: _circleScale,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        blurRadius: 35,
                        spreadRadius: 8,
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF229ED9), Color(0xFF2AABEE)], // Telegram signature gradient
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centered Jet Animating Logo
          Center(
            child: SlideTransition(
              position: _logoOffset,
              child: ScaleTransition(
                scale: _logoScale,
                child: RotationTransition(
                  turns: _logoRotation,
                  child: Image.asset(
                    'assets/icon.png',
                    width: 96,
                    height: 96,
                  ),
                ),
              ),
            ),
          ),
          // Bottom branding text
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _circleFade,
              child: Column(
                children: [
                  const Text(
                    'TelStream',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fast. Secure. Powerful.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
