import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:path_provider/path_provider.dart';
import 'tdlib_service.dart';

class DownloadTask {
  final int fileId;
  final String title;
  final double progress;
  final String? localPath;
  final bool isCompleted;

  DownloadTask({
    required this.fileId,
    required this.title,
    this.progress = 0.0,
    this.localPath,
    this.isCompleted = false,
  });

  DownloadTask copyWith({
    double? progress,
    String? localPath,
    bool? isCompleted,
  }) {
    return DownloadTask(
      fileId: fileId,
      title: title,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class DownloadController extends Notifier<Map<int, DownloadTask>> {
  StreamSubscription? _subscription;

  @override
  Map<int, DownloadTask> build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });
    _init();
    return {};
  }

  Future<void> _init() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDocDir.path}/downloads');
      if (await downloadsDir.exists()) {
        final List<FileSystemEntity> entities = await downloadsDir.list().toList();
        final Map<int, DownloadTask> loadedTasks = {};
        
        for (var entity in entities) {
          if (entity is File) {
            final name = entity.path.split(Platform.pathSeparator).last;
            final separatorIndex = name.indexOf('_');
            if (separatorIndex != -1) {
              final idStr = name.substring(0, separatorIndex);
              final fileId = int.tryParse(idStr);
              if (fileId != null) {
                // Recover safe title (excluding extension)
                final rest = name.substring(separatorIndex + 1);
                final dotIndex = rest.lastIndexOf('.');
                final title = dotIndex != -1 ? rest.substring(0, dotIndex) : rest;
                
                loadedTasks[fileId] = DownloadTask(
                  fileId: fileId,
                  title: title.replaceAll('_', ' '),
                  progress: 1.0,
                  isCompleted: true,
                  localPath: entity.path,
                );
              }
            }
          }
        }
        state = loadedTasks;
      }
    } catch (e) {
      print('Error initializing download directory scan: $e');
    }

    // Listen to tdlib updates for file download progress
    final tdlibService = ref.read(tdlibServiceProvider);
    _subscription = tdlibService.updates.listen((event) {
      if (event is td.UpdateFile) {
        final fileId = event.file.id;
        if (state.containsKey(fileId)) {
          final task = state[fileId]!;
          if (task.isCompleted) return; // Already finished and saved

          final expectedSize = event.file.expectedSize;
          final downloadedSize = event.file.local.downloadedPrefixSize;
          
          double progress = 0.0;
          if (expectedSize > 0) {
            progress = downloadedSize / expectedSize;
          }

          final isCompleted = event.file.local.isDownloadingCompleted;
          String? tempPath = event.file.local.path;

          if (isCompleted && tempPath.isNotEmpty) {
            _saveFilePermanently(fileId, tempPath, task.title);
          } else {
            state = {
              ...state,
              fileId: task.copyWith(
                progress: progress,
                isCompleted: false,
              ),
            };
          }
        }
      }
    });
  }

  Future<void> startDownload(int fileId, String title) async {
    if (state.containsKey(fileId) && state[fileId]!.isCompleted) {
      return; // Already downloaded
    }

    // Register the task in memory
    state = {
      ...state,
      fileId: DownloadTask(fileId: fileId, title: title),
    };

    // Send TDLib DownloadFile command
    ref.read(tdlibServiceProvider).send(td.DownloadFile(
      fileId: fileId,
      priority: 32,
      offset: 0,
      limit: 0,
      synchronous: false,
    ));
  }

  Future<void> _saveFilePermanently(int fileId, String tempPath, String title) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDocDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Safe filename from title
      final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
      
      // Keep extension
      final ext = tempPath.contains('.') ? tempPath.split('.').last : 'mp4';
      final permanentPath = '${downloadsDir.path}/${fileId}_$safeTitle.$ext';

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.copy(permanentPath);
        print('FILE SAVED PERMANENTLY: $permanentPath');
      }

      state = {
        ...state,
        fileId: state[fileId]!.copyWith(
          progress: 1.0,
          isCompleted: true,
          localPath: permanentPath,
        ),
      };
    } catch (e) {
      print('FAILED TO SAVE FILE PERMANENTLY: $e');
    }
  }
}

final downloadControllerProvider = NotifierProvider<DownloadController, Map<int, DownloadTask>>(DownloadController.new);
