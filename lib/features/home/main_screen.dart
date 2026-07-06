import 'dart:io';
import 'package:flutter/material.dart';
import 'android_main_screen.dart';
import 'desktop_main_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    
    if (isDesktop) {
      return const DesktopMainScreen();
    }
    
    return const AndroidMainScreen();
  }
}
