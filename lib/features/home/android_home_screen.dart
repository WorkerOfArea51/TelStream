import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'android_library_view.dart';

class AndroidHomeScreen extends StatelessWidget {
  const AndroidHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Return the default Anime library view
    return AndroidLibraryView(category: Constants.categories[0]);
  }
}
