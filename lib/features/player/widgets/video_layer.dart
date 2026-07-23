import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:telstream/features/player/widgets/cached_video_widget.dart';

class VideoLayer extends StatelessWidget {
  final VideoController controller;
  final ValueNotifier<BoxFit> fitNotifier;
  final ValueNotifier<double?> customAspectRatioNotifier;
  final ValueNotifier<double> scaleNotifier;
  final ValueNotifier<Offset> panNotifier;
  final SubtitleViewConfiguration subtitleConfig;
  final bool isBuffering;
  final bool customBuffering;

  const VideoLayer({
    super.key,
    required this.controller,
    required this.fitNotifier,
    required this.customAspectRatioNotifier,
    required this.scaleNotifier,
    required this.panNotifier,
    required this.subtitleConfig,
    required this.isBuffering,
    required this.customBuffering,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isBuffering || customBuffering)
          const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          ),
        ListenableBuilder(
          listenable: Listenable.merge([
            fitNotifier,
            customAspectRatioNotifier,
            scaleNotifier,
            panNotifier,
          ]),
          builder: (context, _) {
            return Transform.translate(
              offset: panNotifier.value,
              child: Transform.scale(
                scale: scaleNotifier.value,
                child: CachedVideoWidget(
                  controller: controller,
                  fit: fitNotifier.value,
                  customAspectRatio: customAspectRatioNotifier.value,
                  subtitleConfig: subtitleConfig,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
