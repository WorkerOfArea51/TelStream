import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../services/storage_service.dart';

class UserChannelsNotifier extends Notifier<List<UserChannel>> {
  @override
  List<UserChannel> build() {
    return ref.read(storageServiceProvider).getUserChannels();
  }

  Future<void> addChannel(UserChannel channel) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addUserChannel(channel);
    state = storage.getUserChannels();
  }

  Future<void> removeChannel(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeUserChannel(id);
    state = storage.getUserChannels();
  }

  Future<void> refresh() async {
    state = ref.read(storageServiceProvider).getUserChannels();
  }
}

final userChannelsProvider = NotifierProvider<UserChannelsNotifier, List<UserChannel>>(UserChannelsNotifier.new);
