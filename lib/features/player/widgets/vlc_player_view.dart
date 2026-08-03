import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class VlcPlayerView extends StatefulWidget {
  final String videoUrl;
  final String title;
  final VoidCallback onBack;
  final Map<String, String>? httpHeaders;

  const VlcPlayerView({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.onBack,
    this.httpHeaders,
  });

  @override
  State<VlcPlayerView> createState() => _VlcPlayerViewState();
}

class _VlcPlayerViewState extends State<VlcPlayerView> {
  late VlcPlayerController _vlcViewController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _vlcViewController = VlcPlayerController.network(
      widget.videoUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          if (widget.httpHeaders != null)
            for (var entry in widget.httpHeaders!.entries)
              '--http-header=${entry.key}: ${entry.value}'
        ]),
      ),
    );

    _vlcViewController.addListener(() {
      if (_vlcViewController.value.hasError) {
        if (mounted) {
          setState(() {
            _isError = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _vlcViewController.dispose();
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
              'LibVLC failed to load video',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: VlcPlayer(
            controller: _vlcViewController,
            aspectRatio: 16 / 9,
            placeholder: const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          ),
        ),
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
  }
}
