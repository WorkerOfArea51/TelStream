import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/constants.dart';
import '../home/user_channels_provider.dart';
import '../../services/tdlib_service.dart';
import '../../services/channel_resolver.dart';

class UserChannelsScreen extends ConsumerStatefulWidget {
  const UserChannelsScreen({super.key});

  @override
  ConsumerState<UserChannelsScreen> createState() => _UserChannelsScreenState();
}

class _UserChannelsScreenState extends ConsumerState<UserChannelsScreen> {
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  String _selectedIcon = 'custom';
  bool _isAdding = false;
  late final ChannelResolver _resolver;

  @override
  void initState() {
    super.initState();
    _resolver = ChannelResolver(ref.read(tdlibServiceProvider));
  }

  static const _iconOptions = [
    ('custom', Icons.folder_outlined),
    ('movie', Icons.movie_outlined),
    ('tv', Icons.tv_outlined),
    ('anime', Icons.animation_outlined),
    ('music', Icons.music_note_outlined),
    ('docs', Icons.description_outlined),
    ('game', Icons.sports_esports_outlined),
    ('news', Icons.newspaper_outlined),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    final l10n = AppLocalizations.of(context)!;
    _titleController.clear();
    _linkController.clear();
    _selectedIcon = 'custom';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1B26),
          title: Text(l10n.addChannel, style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Channel Name',
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: 'e.g., My Anime Channel',
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _linkController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Telegram Link or @username',
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: 'e.g., @mychannel or https://t.me/...',
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.icon, style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _iconOptions.map((option) {
                    final (name, icon) = option;
                    final isSelected = _selectedIcon == name;
                    return GestureDetector(
                      onTap: () => setDialogState(() => _selectedIcon = name),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? Colors.orange : Colors.transparent),
                        ),
                        child: Icon(icon, color: isSelected ? Colors.orange : Colors.white54, size: 20),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: _isAdding
                  ? null
                  : () async {
                      final title = _titleController.text.trim();
                      final link = _linkController.text.trim();
                      if (link.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.pleaseProvideLinkOrUsername)),
                        );
                        return;
                      }
                      setDialogState(() => _isAdding = true);
                      try {
                        final resolved = await _resolver.resolve(link);
                        final finalTitle = title.isNotEmpty ? title : resolved.title;

                        final channel = UserChannel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: finalTitle,
                          channelId: resolved.channelId,
                          inviteLink: link,
                          icon: _selectedIcon,
                          addedAt: DateTime.now(),
                        );
                        await ref.read(userChannelsProvider.notifier).addChannel(channel);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${l10n.failedToAddChannel}: $e')),
                          );
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => _isAdding = false);
                      }
                    },
              child: _isAdding
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeChannel(UserChannel channel) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1B26),
        title: Text(l10n.removeChannelQuestion, style: TextStyle(color: Colors.white)),
        content: Text(l10n.areYouSureYouWantToRemoveChannel(channel.title), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(userChannelsProvider.notifier).removeChannel(channel.id);
    }
  }

  IconData _getIcon(String iconName) {
    return const {
      'movie': Icons.movie_outlined,
      'tv': Icons.tv_outlined,
      'anime': Icons.animation_outlined,
      'music': Icons.music_note_outlined,
      'docs': Icons.description_outlined,
      'game': Icons.sports_esports_outlined,
      'news': Icons.newspaper_outlined,
      'custom': Icons.folder_outlined,
    }[iconName] ?? Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channels = ref.watch(userChannelsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.myChannels, style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: channels.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(l10n.noChannelsAddedYet, style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(l10n.tapToAddYourFirstChannel, style: TextStyle(color: Colors.white24, fontSize: 13)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addChannel),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return Card(
                  color: const Color(0xFF1A1B26),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getIcon(channel.icon), color: Colors.orange),
                    ),
                    title: Text(channel.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'ID: ${channel.channelId}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeChannel(channel),
                    ),
                  ),
                );
              },
            ),
    );
  }
}


