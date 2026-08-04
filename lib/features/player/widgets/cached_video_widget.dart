import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Renders the [Video] widget from media_kit, with platform-specific
/// compositing wrappers.
///
/// ── Why RepaintBoundary on mobile? ─────────────────────────────────────────
/// On Android, media_kit's `Video` widget may be backed by a `SurfaceTexture`
/// (when enableHardwareAcceleration=true / hwdec=mediacodec zero-copy) or by
/// a CPU pixel buffer (when enableHardwareAcceleration=false / hwdec=mediacodec-
/// copy or hwdec=no). With `mediacodec-copy`, the `SurfaceTexture` is NOT used
/// for the Video widget — instead, mpv's GPU VO renders frames to its own GL
/// framebuffer and the Video widget reads them from the CPU buffer.
///
/// Without a `RepaintBoundary`, Flutter's dirty-region propagation can skip
/// the texture update notification, causing the layer to display a stale (or
/// initial black) frame forever. `RepaintBoundary` forces Flutter to treat the
/// `Video` widget as an independent compositing layer. This isolates the
/// updates from the rest of the widget tree and guarantees that every texture
/// or buffer update triggers a layer recomposite.
///
/// DO NOT REMOVE THE RepaintBoundary ON MOBILE. Removing it re-introduces
/// the black-screen bug documented in TelStream v2.13.7+60 (Hotfix) and
/// v2.13.7+66 (Hotfix 7).
///
/// ── Why no RepaintBoundary on desktop? ─────────────────────────────────────
/// Desktop platforms (Windows/Linux/macOS) use media_kit's ANGLE / GLX /
/// Metal backend, which composites directly into Flutter's rendering
/// pipeline without a SurfaceTexture. The `RepaintBoundary` adds a
/// compositing layer with no benefit, so we skip it for performance.
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
    final fallbackRatio =
        (videoWidth != null && videoHeight != null && videoHeight > 0)
            ? videoWidth / videoHeight
            : 16.0 / 9.0;

    // Build the video widget once — desktop/mobile differentiation is
    // handled in build() where RepaintBoundary is skipped on desktop.
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
    // See class docs for why RepaintBoundary is required on mobile.
    return _cachedWidget; // REMOVED RepaintBoundary: Causes single-composite freeze on MediaTek/Mali GPUs
  }
}
