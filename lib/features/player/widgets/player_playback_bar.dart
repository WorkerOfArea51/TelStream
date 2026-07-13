import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class VideoChapter {
  final String title;
  final Duration position;

  const VideoChapter({required this.title, required this.position});
}

class PlayerSeekBar extends StatefulWidget {
  final Player player;
  final String seekbarStyle;
  final Color settingsAccent;
  final int downloadedPrefixSize;
  final int expectedSize;
  final int activeDownloadOffset;
  final int activeDownloadedSize;
  final List<VideoChapter> chapters;
  final VoidCallback cancelHideTimer;
  final VoidCallback startHideTimer;
  final bool Function(Duration) isPositionDownloaded;
  final void Function(Duration) throttledSeek;
  final Duration Function(Duration) clampSeekTarget;
  final void Function(Duration) onSeekPerformed;

  const PlayerSeekBar({
    super.key,
    required this.player,
    required this.seekbarStyle,
    required this.settingsAccent,
    required this.downloadedPrefixSize,
    required this.expectedSize,
    required this.activeDownloadOffset,
    required this.activeDownloadedSize,
    required this.chapters,
    required this.cancelHideTimer,
    required this.startHideTimer,
    required this.isPositionDownloaded,
    required this.throttledSeek,
    required this.clampSeekTarget,
    required this.onSeekPerformed,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _draggingValue;

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hrs = d.inHours;
      final m = (min % 60).toString().padLeft(2, '0');
      return '$hrs:$m:$sec';
    }
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final bufferedBytes = math.max(widget.downloadedPrefixSize, widget.activeDownloadOffset + widget.activeDownloadedSize);
    double downloadedRatio = widget.expectedSize > 0
        ? (bufferedBytes / widget.expectedSize).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        StreamBuilder<Duration>(
          stream: widget.player.stream.position,
          builder: (context, snapshot) {
            final pos = snapshot.data ?? widget.player.state.position;
            final displayPos = _draggingValue != null
                ? Duration(milliseconds: _draggingValue!.toInt())
                : pos;
            return Text(_formatDuration(displayPos), style: const TextStyle(color: Colors.white));
          },
        ),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: widget.player.stream.position,
            builder: (context, posSnap) {
              return StreamBuilder<Duration>(
                stream: widget.player.stream.duration,
                builder: (context, durSnap) {
                  final pos = posSnap.data ?? widget.player.state.position;
                  final dur = durSnap.data ?? widget.player.state.duration;
                  double maxVal = dur.inMilliseconds.toDouble();
                  if (maxVal == 0) maxVal = pos.inMilliseconds.toDouble(); // fallback
                  final val = pos.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

                  final SliderTrackShape baseTrackShape = widget.seekbarStyle == 'Wavy'
                      ? WavySliderTrackShape()
                      : widget.seekbarStyle == 'Thick'
                          ? const RectangularSliderTrackShape()
                          : const RoundedRectSliderTrackShape();

                  final trackShape = ChapterSliderTrackShape(
                    delegate: baseTrackShape,
                    chapters: widget.chapters,
                    totalDuration: dur,
                  );

                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: widget.seekbarStyle == 'Thick' ? 10.0 : 6.0,
                      trackShape: trackShape,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      secondaryActiveTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxVal > 0 ? maxVal : 1.0,
                      value: _draggingValue ?? val,
                      secondaryTrackValue: (maxVal * downloadedRatio).clamp(0.0, maxVal),
                      onChangeStart: (_) {
                        widget.cancelHideTimer();
                        setState(() {
                          _draggingValue = val;
                        });
                      },
                      onChanged: maxVal > 0
                          ? (v) {
                              setState(() {
                                _draggingValue = v;
                              });
                              final target = Duration(milliseconds: v.toInt());
                              if (widget.isPositionDownloaded(target)) {
                                widget.throttledSeek(target);
                              }
                            }
                          : null,
                      onChangeEnd: (v) {
                        widget.startHideTimer();
                        final target = Duration(milliseconds: v.toInt());
                        final safeTarget = widget.clampSeekTarget(target);
                        widget.onSeekPerformed(safeTarget);
                        setState(() {
                          _draggingValue = null;
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          builder: (context, snapshot) {
            final dur = snapshot.data ?? widget.player.state.duration;
            return Text(dur.inSeconds == 0 ? '--:--' : _formatDuration(dur), style: const TextStyle(color: Colors.white));
          },
        ),
      ],
    );
  }
}

class WavySliderTrackShape extends RectangularSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint secondaryPaint = Paint()
      ..color = sliderTheme.secondaryActiveTrackColor ?? (sliderTheme.activeTrackColor?.withValues(alpha: 0.35) ?? Colors.blueAccent.withValues(alpha: 0.35))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path activePath = Path();
    final Path secondaryPath = Path();
    final Path inactivePath = Path();

    const double waveAmplitude = 4.0;
    const double waveWavelength = 24.0;

    bool firstActive = true;
    bool firstSecondary = true;
    bool firstInactive = true;
    
    final double midY = trackRect.top + trackRect.height / 2;
    final double secondaryX = secondaryOffset?.dx ?? thumbCenter.dx;

    for (double x = trackRect.left; x <= trackRect.right; x += 1.0) {
      final double relativeX = x - trackRect.left;
      final double y = midY + waveAmplitude * math.sin(relativeX * 2 * math.pi / waveWavelength);

      if (x <= thumbCenter.dx) {
        if (firstActive) {
          activePath.moveTo(x, y);
          firstActive = false;
        } else {
          activePath.lineTo(x, y);
        }
      } else if (x <= secondaryX) {
        if (firstSecondary) {
          secondaryPath.moveTo(x - 1, y);
          secondaryPath.lineTo(x, y);
          firstSecondary = false;
        } else {
          secondaryPath.lineTo(x, y);
        }
      } else {
        if (firstInactive) {
          inactivePath.moveTo(x - 1, midY);
          inactivePath.lineTo(x, y);
          firstInactive = false;
        } else {
          inactivePath.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(activePath, activePaint);
    if (secondaryX > thumbCenter.dx) {
      canvas.drawPath(secondaryPath, secondaryPaint);
    }
    canvas.drawPath(inactivePath, inactivePaint);
  }
}

class ChapterSliderTrackShape extends SliderTrackShape {
  final SliderTrackShape delegate;
  final List<VideoChapter> chapters;
  final Duration totalDuration;

  ChapterSliderTrackShape({
    required this.delegate,
    required this.chapters,
    required this.totalDuration,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    return delegate.getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    delegate.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    if (chapters.isEmpty || totalDuration.inMilliseconds <= 0) return;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final double trackWidth = trackRect.width;
    final double trackLeft = trackRect.left;

    final Canvas canvas = context.canvas;
    final Paint tickPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final chapter in chapters) {
      final double fraction = chapter.position.inMilliseconds / totalDuration.inMilliseconds;
      if (fraction <= 0.0 || fraction >= 1.0) continue;

      final double tickX = trackLeft + fraction * trackWidth;

      canvas.drawLine(
        Offset(tickX, trackRect.top - 1.0),
        Offset(tickX, trackRect.bottom + 1.0),
        tickPaint,
      );
    }
  }
}
