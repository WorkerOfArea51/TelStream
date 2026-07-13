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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
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
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: Colors.orange, size: 28),
              ),
              title: Text(
                channel.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                channel.inviteLink ?? 'Channel ID: ${channel.channelId}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
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
            ),
          );
        },
      ),
    );
  }
}
