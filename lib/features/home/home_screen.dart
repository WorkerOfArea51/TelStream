import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'library_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Return the default Anime library view
    return LibraryView(category: Constants.categories[0]);
  }
}
