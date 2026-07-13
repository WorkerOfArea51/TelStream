import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import 'user_channels_provider.dart';
import 'android_library_view.dart';

class UserChannelsHomeScreen extends ConsumerStatefulWidget {
  final bool isActive;
  const UserChannelsHomeScreen({super.key, this.isActive = false});

  @override
  ConsumerState<UserChannelsHomeScreen> createState() => _UserChannelsHomeScreenState();
}

class _UserChannelsHomeScreenState extends ConsumerState<UserChannelsHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(userChannelsProvider);
    final theme = Theme.of(context);

    if (channels.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('No channels added yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Go to More → My Channels to add your own channels', 
                style: TextStyle(color: Colors.white24, fontSize: 13),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Channels'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final IconData iconData = const {
            'movie': Icons.movie_outlined,
            'tv': Icons.tv_outlined,
            'anime': Icons.animation_outlined,
            'music': Icons.music_note_outlined,
            'docs': Icons.description_outlined,
            'game': Icons.sports_esports_outlined,
            'news': Icons.newspaper_outlined,
            'custom': Icons.folder_outlined,
          }[channel.icon] ?? Icons.folder_outlined;

          // Convert UserChannel to ChannelCategory so AndroidLibraryView can use it
          final category = ChannelCategory(
            title: channel.title,
            channelId: channel.channelId,
            inviteLink: channel.inviteLink ?? '',
          );

          return Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AndroidLibraryView(
                      category: category,
                      isActive: true,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(iconData, color: Colors.orange, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      channel.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.inviteLink ?? 'ID: ${channel.channelId}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
