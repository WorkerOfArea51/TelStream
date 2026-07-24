import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SleepTimerDialog extends StatefulWidget {
  final int? remainingSeconds;
  final int? currentMinutes;
  final Function(int) onStartTimer;
  final Function(int) onStartTimerSeconds;
  final VoidCallback onCancelTimer;

  const SleepTimerDialog({
    super.key,
    required this.remainingSeconds,
    required this.currentMinutes,
    required this.onStartTimer,
    required this.onStartTimerSeconds,
    required this.onCancelTimer,
  });

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  int? _sleepTimerMinutes;

  @override
  void initState() {
    super.initState();
    _sleepTimerMinutes = widget.currentMinutes;
  }

  String _formatSleepTimeRemaining(int seconds) {
    if (seconds < 0) return '00:00';
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xE60F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.snooze, color: settingsAccent, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Sleep Timer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select when the video should stop playing and close.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                if (widget.remainingSeconds != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: settingsAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: settingsAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Timer: ${_formatSleepTimeRemaining(widget.remainingSeconds!)}',
                          style: TextStyle(
                            color: settingsAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onCancelTimer();
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Cancel Timer',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [15, 30, 45, 60].map((mins) {
                    final isSelected = _sleepTimerMinutes == mins;
                    return InkWell(
                      onTap: () {
                        setState(() => _sleepTimerMinutes = mins);
                        widget.onStartTimer(mins);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? settingsAccent
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? settingsAccent : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$mins',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mins',
                              style: TextStyle(
                                color: isSelected ? Colors.black87 : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      widget.onStartTimerSeconds(10);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Test with 10s',
                      style: TextStyle(
                        color: settingsAccent.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
