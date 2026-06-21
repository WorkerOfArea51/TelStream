import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../player/pip_manager.dart';
import '../../services/storage_service.dart';

class NetworkStreamScreen extends ConsumerStatefulWidget {
  const NetworkStreamScreen({super.key});

  @override
  ConsumerState<NetworkStreamScreen> createState() => _NetworkStreamScreenState();
}

class _NetworkStreamScreenState extends ConsumerState<NetworkStreamScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _playStream() {
    if (_formKey.currentState!.validate()) {
      final url = _urlController.text.trim();
      
      ref.read(recentNetworkStreamsProvider.notifier).addStream(url);
      
      // We extract filename from URL or use a default title
      String fileName = 'Network Stream';
      try {
        final uri = Uri.parse(url);
        if (uri.pathSegments.isNotEmpty) {
          fileName = uri.pathSegments.last;
        }
      } catch (_) {}

      // Play using the PiP controller with dummy message/file IDs (0)
      ref.read(pipControllerProvider.notifier).playVideo(
        context,
        messageId: 0,
        videoFileId: 0,
        videoTitle: fileName,
        networkUrl: url,
      );
    }
  }

  void _playStreamDirect(String url) {
    ref.read(recentNetworkStreamsProvider.notifier).addStream(url);
    
    String fileName = 'Network Stream';
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        fileName = uri.pathSegments.last;
      }
    } catch (_) {}

    ref.read(pipControllerProvider.notifier).playVideo(
      context,
      messageId: 0,
      videoFileId: 0,
      videoTitle: fileName,
      networkUrl: url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentStreams = ref.watch(recentNetworkStreamsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Network Stream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Play external URL',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter a direct link to a video file (HTTP/HTTPS) to play it in the high-performance player.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://example.com/video.mp4',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.link, color: Colors.orange),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () => _urlController.clear(),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'URL cannot be empty';
                  }
                  final trimmed = value.trim().toLowerCase();
                  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                    return 'Enter a valid HTTP or HTTPS URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _playStream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text(
                    'Play Stream',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (recentStreams.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  children: const [
                    Icon(Icons.history, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Recent Streams',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: recentStreams.length,
                    itemBuilder: (context, index) {
                      final url = recentStreams[index];
                      String title = url;
                      try {
                        final uri = Uri.parse(url);
                        if (uri.pathSegments.isNotEmpty) {
                          title = uri.pathSegments.last;
                        }
                      } catch (_) {}
                      
                      return Card(
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: const Icon(Icons.link, color: Colors.white54),
                          title: Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            url,
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () {
                              ref.read(recentNetworkStreamsProvider.notifier).removeStream(url);
                            },
                          ),
                          onTap: () => _playStreamDirect(url),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
