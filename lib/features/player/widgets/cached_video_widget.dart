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

    // Build the video widget once — desktop/mobile differentiation is handled
    // in build() where RepaintBoundary is skipped on desktop
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
    return isDesktop ? _cachedWidget : RepaintBoundary(child: _cachedWidget);
  }
}
