import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ExoPlayerView extends StatefulWidget {
  final String videoUrl;
  final String title;
  final VoidCallback onBack;
  final Map<String, String>? httpHeaders;

  const ExoPlayerView({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.onBack,
    this.httpHeaders,
  });

  @override
  State<ExoPlayerView> createState() => _ExoPlayerViewState();
}

class _ExoPlayerViewState extends State<ExoPlayerView> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: widget.httpHeaders ?? {},
    );
    
    try {
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        customControls: const MaterialControls(),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'ExoPlayer failed to load video',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Stack(
        children: [
          Chewie(controller: _chewieController!),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),
        ],
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }
  }
}
