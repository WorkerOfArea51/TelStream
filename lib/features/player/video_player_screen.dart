import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../settings/settings_provider.dart';
import 'pip_manager.dart';
import 'custom_video_controls.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final List<td.Message>? episodeList;
  final int? currentEpisodeIndex;
  final String seriesName;
  final bool isPip;
  final String? networkUrl;
  
  const VideoPlayerScreen({
    Key? key, 
    required this.messageId, 
    required this.videoFileId, 
    this.videoTitle = '',
    this.episodeList,
    this.currentEpisodeIndex,
    this.seriesName = '',
    this.isPip = false,
    this.networkUrl,
  }) : super(key: key);

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  StreamSubscription? _updatesSubscription;
  bool _isPlaying = false;
  int _downloadedPrefixSize = 0;
  int _expectedSize = 0;

  StreamSubscription? _completedSubscription;
  Timer? _saveTimer;

  late final StorageService _storageService;
  late final TdlibService _tdlibService;
  late final PipController _pipController;
  late final VideoSettings _settings;

  @override
  void initState() {
    super.initState();
    
    _storageService = ref.read(storageServiceProvider);
    _tdlibService = ref.read(tdlibServiceProvider);
    _pipController = ref.read(pipControllerProvider.notifier);
    _settings = ref.read(videoSettingsProvider);
    
    player = Player(
      configuration: PlayerConfiguration(
        pitch: _settings.pitchCorrection,
      ),
    );
    _pipController.setActivePlayer(player);
    controller = VideoController(player);
    
    _startDownload();
    
    // Auto-Play Next Episode Logic
    _completedSubscription = player.stream.completed.listen((completed) {
      if (completed && _settings.autoplayNextVideo && widget.episodeList != null && widget.currentEpisodeIndex != null) {
        if (widget.currentEpisodeIndex! + 1 < widget.episodeList!.length) {
          _playNextEpisode();
        }
      }
    });

    // Periodic Save for Continue Watching
    if (widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
      Future.microtask(() {
        if (mounted) {
          ref.read(lastWatchedProvider.notifier).updateLastWatched(
            widget.seriesName,
            widget.messageId,
            widget.currentEpisodeIndex!,
          );
        }
      });
    }

    _saveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_settings.savePositionOnQuit && player.state.position.inSeconds > 0) {
        _storageService.saveWatchPosition(widget.messageId, player.state.position.inSeconds);
        if (!_storageService.isIncognitoMode() && widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
          ref.read(historyLogProvider.notifier).addToHistory(
            seriesName: widget.seriesName,
            messageId: widget.messageId,
            episodeIndex: widget.currentEpisodeIndex!,
            episodeTitle: widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
            positionInSeconds: player.state.position.inSeconds,
          );
        }
      }
    });
  }

  void _playNextEpisode() {
    final nextIndex = widget.currentEpisodeIndex! + 1;
    final nextMsg = widget.episodeList![nextIndex];
    int? nextFileId;
    String nextTitle = 'Episode ${nextIndex + 1}';
    
    if (nextMsg.content is td.MessageVideo) {
      final v = nextMsg.content as td.MessageVideo;
      nextFileId = v.video.video.id;
      nextTitle = v.video.fileName;
    } else if (nextMsg.content is td.MessageDocument) {
      final d = nextMsg.content as td.MessageDocument;
      nextFileId = d.document.document.id;
      nextTitle = d.document.fileName;
    }

    if (nextFileId != null) {
      ref.read(pipControllerProvider.notifier).playVideo(
        context,
        messageId: nextMsg.id,
        videoFileId: nextFileId,
        videoTitle: '${widget.seriesName} - $nextTitle',
        episodeList: widget.episodeList,
        currentEpisodeIndex: nextIndex,
        seriesName: widget.seriesName,
      );
    }
  }

  void _playPreviousEpisode() {
    if (widget.currentEpisodeIndex == null || widget.currentEpisodeIndex! <= 0 || widget.episodeList == null) return;
    final prevIndex = widget.currentEpisodeIndex! - 1;
    final prevMsg = widget.episodeList![prevIndex];
    int? prevFileId;
    String prevTitle = 'Episode ${prevIndex + 1}';
    
    if (prevMsg.content is td.MessageVideo) {
      final v = prevMsg.content as td.MessageVideo;
      prevFileId = v.video.video.id;
      prevTitle = v.video.fileName;
    } else if (prevMsg.content is td.MessageDocument) {
      final d = prevMsg.content as td.MessageDocument;
      prevFileId = d.document.document.id;
      prevTitle = d.document.fileName;
    }

    if (prevFileId != null) {
      ref.read(pipControllerProvider.notifier).playVideo(
        context,
        messageId: prevMsg.id,
        videoFileId: prevFileId,
        videoTitle: '${widget.seriesName} - $prevTitle',
        episodeList: widget.episodeList,
        currentEpisodeIndex: prevIndex,
        seriesName: widget.seriesName,
      );
    }
  }

  DateTime? _lastUpdateTime;

  void _startDownload() {
    if (widget.networkUrl != null && widget.networkUrl!.isNotEmpty) {
      _isPlaying = true;
      player.open(Media(widget.networkUrl!));
      player.setVolume(100.0);
      return;
    }

    _updatesSubscription = _tdlibService.updates.listen((event) {
      if (event is td.UpdateFile && event.file.id == widget.videoFileId) {
        final localPath = event.file.local.path;
        
        final now = DateTime.now();
        if (_lastUpdateTime == null || now.difference(_lastUpdateTime!).inMilliseconds > 500 || event.file.local.isDownloadingCompleted) {
          _lastUpdateTime = now;
          if (mounted) {
            setState(() {
              _downloadedPrefixSize = event.file.local.downloadedPrefixSize;
              _expectedSize = event.file.expectedSize;
            });
          }
        }

        if (localPath.isNotEmpty && !_isPlaying) {
          if (event.file.local.isDownloadingCompleted || event.file.local.downloadedPrefixSize > 2 * 1024 * 1024) {
            _isPlaying = true;
            player.open(Media(localPath));
            player.setVolume(100.0);
            
            final savedPos = _storageService.getWatchPosition(widget.messageId);
            if (savedPos > 0) {
              player.seek(Duration(seconds: savedPos));
            }
          }
        }
      }
    });

    _tdlibService.send(td.DownloadFile(
      fileId: widget.videoFileId,
      priority: 32,
      offset: 0,
      limit: 0,
      synchronous: false,
    ));
  }

  @override
  void dispose() {
    try {
      player.pause();
      player.stop();
    } catch (_) {}

    _updatesSubscription?.cancel();
    _completedSubscription?.cancel();
    _saveTimer?.cancel();
    
    try {
      final position = player.state.position.inSeconds;
      if (position > 0 && _settings.savePositionOnQuit) {
        _storageService.saveWatchPosition(widget.messageId, position);
        if (!_storageService.isIncognitoMode() && widget.seriesName.isNotEmpty && widget.currentEpisodeIndex != null) {
          ref.read(historyLogProvider.notifier).addToHistory(
            seriesName: widget.seriesName,
            messageId: widget.messageId,
            episodeIndex: widget.currentEpisodeIndex!,
            episodeTitle: widget.videoTitle.replaceFirst('${widget.seriesName} - ', ''),
            positionInSeconds: position,
          );
        }
      }
    } catch (_) {}

    try {
      player.dispose();
    } catch (_) {}

    if (_pipController.activePlayer == player) {
      _pipController.clearActivePlayer(player);
    }
    
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}

    try {
      _tdlibService.send(td.CancelDownloadFile(fileId: widget.videoFileId, onlyIfPending: false));
      _tdlibService.send(td.DeleteFile(fileId: widget.videoFileId)); 
    } catch (_) {}
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPip) {
      return GestureDetector(
        onTap: () {
          ref.read(pipControllerProvider.notifier).maximize();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Video(controller: controller, controls: NoVideoControls),
              Positioned(
                top: 0, 
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(pipControllerProvider.notifier).close();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(pipControllerProvider.notifier).minimize();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _isPlaying 
            ? CustomVideoControls(
                player: player,
                controller: controller,
                videoTitle: widget.videoTitle,
                isPip: widget.isPip,
                downloadedPrefixSize: _downloadedPrefixSize,
                expectedSize: _expectedSize,
                onBack: () => ref.read(pipControllerProvider.notifier).minimize(),
                hasPrevEpisode: widget.episodeList != null && widget.currentEpisodeIndex != null && widget.currentEpisodeIndex! > 0,
                hasNextEpisode: widget.episodeList != null && widget.currentEpisodeIndex != null && widget.currentEpisodeIndex! + 1 < widget.episodeList!.length,
                onPrevEpisode: _playPreviousEpisode,
                onNextEpisode: _playNextEpisode,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text('Buffering stream from Telegram...', style: TextStyle(color: Colors.white70)),
                  if (_expectedSize > 0)
                    Text('${(_downloadedPrefixSize / 1024 / 1024).toStringAsFixed(1)} MB / ${(_expectedSize / 1024 / 1024).toStringAsFixed(1)} MB', style: const TextStyle(color: Colors.white54)),
                ],
              ),
        ),
      ),
    );
  }
}
