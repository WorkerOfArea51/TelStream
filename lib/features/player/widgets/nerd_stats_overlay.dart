import 'package:flutter/material.dart';

class NerdStatsOverlay extends StatelessWidget {
  final Map<String, String> nerdStats;

  const NerdStatsOverlay({
    super.key,
    required this.nerdStats,
  });

  @override
  Widget build(BuildContext context) {
    if (nerdStats.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 250,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stats for Nerds',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white12, height: 8),
            ...nerdStats.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
