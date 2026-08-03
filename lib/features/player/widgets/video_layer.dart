import 'dart:io';
import 'package:flutter/material.dart';



class VideoLayer extends StatelessWidget {
  final Widget Function(BuildContext context, BoxFit fit, double? customAspectRatio) videoSurfaceBuilder;
  final ValueNotifier<BoxFit> fitNotifier;
  final ValueNotifier<double?> customAspectRatioNotifier;
  final ValueNotifier<double> scaleNotifier;
  final ValueNotifier<Offset> panNotifier;
  
  final bool isBuffering;
  final bool customBuffering;

  const VideoLayer({
    super.key,
    required this.videoSurfaceBuilder,
    required this.fitNotifier,
    required this.customAspectRatioNotifier,
    required this.scaleNotifier,
    required this.panNotifier,
    
    required this.isBuffering,
    required this.customBuffering,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    // On desktop, skip Transform wrappers entirely — pinch-zoom/pan gestures
    // are disabled on desktop, so these transforms always operate at identity
    // (scale=1.0, pan=Offset.zero). Removing them eliminates unnecessary
    // compositing layers that add overhead to desktop video rendering.
    if (isDesktop) {
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
            ]),
            builder: (context, _) {
              return videoSurfaceBuilder(context, fitNotifier.value, customAspectRatioNotifier.value);
            },
          ),
        ],
      );
    }

    // On mobile, keep Transform wrappers for pinch-zoom/pan gesture support
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
                child: videoSurfaceBuilder(context, fitNotifier.value, customAspectRatioNotifier.value),
              ),
            );
          },
        ),
      ],
    );
  }
}
