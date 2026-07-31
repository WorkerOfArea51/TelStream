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
    // in build() where RepaintBoundary is skipped on desktop AND on Android.
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
    // v2.13.7 — CRITICAL FIX for Android black-screen-with-audio:
    //
    // Previously this widget wrapped the `Video` media_kit widget in a
    // `RepaintBoundary` on mobile (Android + iOS). On Android, when
    // `hwdec=mediacodec-copy` is used with `vo=gpu`, the decoded frame is
    // uploaded to an OpenGL texture that backs the Flutter `SurfaceTexture`.
    //
    // `RepaintBoundary` creates a separate compositing layer with its own
    // retained layer handle. On some Android devices (notably older Mali
    // and Adreno GPU drivers), the texture update signal from media_kit's
    // native side doesn't reliably propagate through the RepaintBoundary
    // layer — the layer keeps displaying the first (empty/black) frame
    // forever, even though the underlying texture is being updated.
    //
    // The result: audio plays, MPV's position advances, but the video
    // surface stays black.
    //
    // FIX: Skip the RepaintBoundary wrapper on Android. The slight compositing
    // overhead is worth it for reliable frame delivery. iOS keeps the
    // RepaintBoundary because it doesn't use mediacodec and doesn't have
    // this issue. Desktop skips it for performance reasons (as before).
    final isAndroid = Platform.isAndroid;
    if (isDesktop || isAndroid) {
      return _cachedWidget;
    }
    return RepaintBoundary(child: _cachedWidget);
  }
}
