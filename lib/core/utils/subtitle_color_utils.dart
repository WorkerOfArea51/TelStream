import 'package:flutter/material.dart';

class SubtitleColorUtils {
  static const List<Map<String, String>> colors = [
    {'name': 'White', 'hex': '#FFFFFF'},
    {'name': 'Black', 'hex': '#000000'},
    {'name': 'Yellow', 'hex': '#FFFF00'},
    {'name': 'Green', 'hex': '#00FF00'},
    {'name': 'Red', 'hex': '#FF0000'},
    {'name': 'Cyan', 'hex': '#00FFFF'},
    {'name': 'Blue', 'hex': '#0000FF'},
    {'name': 'Orange', 'hex': '#FFA500'},
    {'name': 'Magenta', 'hex': '#FF00FF'},
  ];

  static Color parseColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return Colors.white;
  }
}
