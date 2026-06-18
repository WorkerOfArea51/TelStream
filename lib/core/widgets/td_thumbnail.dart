import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../services/tdlib_service.dart';
import '../logger.dart';

class TdThumbnail extends ConsumerStatefulWidget {
  final td.File? file;
  final td.Minithumbnail? minithumbnail;
  final bool autoDownload;
  final double width;
  final double height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  
  const TdThumbnail({
    Key? key, 
    required this.file, 
    this.minithumbnail,
    this.autoDownload = true,
    this.width = 80, 
    this.height = 60,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
  }) : super(key: key);

  @override
  ConsumerState<TdThumbnail> createState() => _TdThumbnailState();
}

class _TdThumbnailState extends ConsumerState<TdThumbnail> {
  String? _localPath;
  StreamSubscription? _sub;
  late final TdlibService _tdlibService;
  
  @override
  void initState() {
    super.initState();
    _tdlibService = ref.read(tdlibServiceProvider);
    _initThumbnail(isInit: true);
  }
  
  @override
  void didUpdateWidget(TdThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file?.id != widget.file?.id) {
      _initThumbnail(isInit: false);
    }
  }

  void _initThumbnail({required bool isInit}) {
    _sub?.cancel();
    if (widget.file == null) {
      if (isInit) {
        _localPath = null;
      } else {
        setState(() => _localPath = null);
      }
      return;
    }
    
    final file = widget.file!;
    if (file.local.path.isNotEmpty && File(file.local.path).existsSync()) {
      if (isInit) {
        _localPath = file.local.path;
      } else {
        setState(() => _localPath = file.local.path);
      }
    } else {
      if (isInit) {
        _localPath = null;
      } else {
        setState(() => _localPath = null);
      }
      _sub = _tdlibService.updates.listen((event) {
        if (event is td.UpdateFile && event.file.id == file.id) {
          if (event.file.local.path.isNotEmpty && File(event.file.local.path).existsSync() && mounted) {
            setState(() => _localPath = event.file.local.path);
          }
        }
      });
      
      if (widget.autoDownload) {
        _tdlibService.send(td.DownloadFile(
          fileId: file.id,
          priority: 1,
          offset: 0,
          limit: 0,
          synchronous: false,
        ));
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (widget.file != null && _localPath == null) {
      try {
        _tdlibService.send(td.CancelDownloadFile(
          fileId: widget.file!.id,
          onlyIfPending: true,
        ));
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _localPath;
    final fileExists = imagePath != null && File(imagePath).existsSync();

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF0F172A), // Slate 900
        child: fileExists
            ? Image.file(
                File(imagePath),
                fit: widget.fit,
                alignment: widget.alignment,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder();
                },
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final mini = widget.minithumbnail;
    if (mini != null && mini.data.isNotEmpty) {
      try {
        final bytes = base64Decode(mini.data);
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
          ),
        );
      } catch (e, stackTrace) {
        Log.e("Error decoding minithumbnail", e, stackTrace);
      }
    }

    return const Center(
      child: Icon(
        Icons.movie,
        color: Colors.white24,
        size: 40,
      ),
    );
  }
}
