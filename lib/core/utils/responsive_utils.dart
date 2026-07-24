import 'package:flutter/material.dart';

int responsiveCrossAxisCount(BuildContext context, {int baseCount = 2, int maxCount = 8, double itemWidth = 150}) {
  final width = MediaQuery.of(context).size.width;
  int count = (width / itemWidth).floor();
  if (count < baseCount) return baseCount;
  if (count > maxCount) return maxCount;
  return count;
}
