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
    _cachedWidget = widget.customAspectRatio != null
        ? Center(
            child: AspectRatio(
              aspectRatio: widget.customAspectRatio!,
              child: Video(
                key: ValueKey(widget.controller),
                controller: widget.controller,
                controls: NoVideoControls,
                fit: BoxFit.fill,
                subtitleViewConfiguration: widget.subtitleConfig,
              ),
            ),
          )
        : Video(
            key: ValueKey(widget.controller),
            controller: widget.controller,
            controls: NoVideoControls,
            fit: widget.fit,
            subtitleViewConfiguration: widget.subtitleConfig,
          );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: _cachedWidget);
  }
}
