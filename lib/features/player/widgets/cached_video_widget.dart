import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CachedVideoWidget extends StatefulWidget {
  final VideoController controller;
  final BoxFit fit;
  final double? customAspectRatio;
  final SubtitleViewConfiguration subtitleConfig;

  const CachedVideoWidget({
    super.key,
    required this.controller,
    required this.fit,
    this.customAspectRatio,
    required this.subtitleConfig,
  });

  @override
  State<CachedVideoWidget> createState() => _CachedVideoWidgetState();
}

class _CachedVideoWidgetState extends State<CachedVideoWidget> {
  late Widget _cachedWidget;

  @override
  void initState() {
    super.initState();
    _buildCachedWidget();
  }

  @override
  void didUpdateWidget(CachedVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.fit != widget.fit ||
        oldWidget.customAspectRatio != widget.customAspectRatio ||
        oldWidget.subtitleConfig != widget.subtitleConfig) {
      _buildCachedWidget();
    }
  }

  void _buildCachedWidget() {
    final videoWidth = widget.controller.player.state.width;
    final videoHeight = widget.controller.player.state.height;
    final fallbackRatio = (videoWidth != null && videoHeight != null && videoHeight > 0)
        ? videoWidth / videoHeight
        : 16.0 / 9.0;

    // Build the video widget once - desktop/mobile differentiation is handled
    // in build() where RepaintBoundary is skipped on ALL platforms.
    _cachedWidget = Center(
      child: AspectRatio(
        aspectRatio: widget.customAspectRatio ?? fallbackRatio,
        child: Video(
          key: ValueKey(widget.controller),
          controller: widget.controller,
          controls: NoVideoControls,
          fit: widget.customAspectRatio != null ? BoxFit.fill : widget.fit,
          subtitleViewConfiguration: widget.subtitleConfig,
          wakelock: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) {
      return _cachedWidget;
    }
    // v2.13.8 FIX — Android black-screen-with-audio.
    //
    // The v2.13.7 changelog claimed RepaintBoundary was removed on Android;
    // it was not. Wrapping media_kit's Video widget (which is a Texture
    // widget backed by an asynchronously-updated SurfaceTexture) in a
    // RepaintBoundary breaks texture frame propagation on many
    // MediaTek/Mali/Adreno GPU+driver combinations. The offscreen layer
    // composites once and then never refreshes, producing a permanent
    // black screen even though mpv is correctly decoding frames.
    //
    // The comment at line ~51 already claims this is skipped on Android
    // — v2.13.7 shipped without actually applying it. This is the fix.
    return _cachedWidget;
  }
}
