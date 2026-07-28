import 'package:tdlib/td_api.dart' as td;

int extractFileSize(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.video.expectedSize;
  if (c is td.MessageDocument) return c.document.document.expectedSize;
  return 0;
}

String extractFileName(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.fileName;
  if (c is td.MessageDocument) return c.document.fileName;
  return '';
}

String extractMimeType(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.mimeType;
  if (c is td.MessageDocument) return c.document.mimeType;
  return '';
}

/// Extracts the base64-encoded JPEG minithumbnail from a video or document
/// message. Returns null if Telegram didn't generate one.
String? extractMinithumbnailData(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.minithumbnail?.data;
  if (c is td.MessageDocument) return c.document.minithumbnail?.data;
  return null;
}

/// Extracts the TDLib file ID of the full-quality thumbnail from a video or
/// document message. Returns null if Telegram didn't generate a thumbnail.
int? extractThumbnailFileId(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.thumbnail?.file.id;
  if (c is td.MessageDocument) return c.document.thumbnail?.file.id;
  return null;
}

/// Extracts TDLib-provided duration in seconds. Only MessageVideo has this —
/// MessageDocument returns null (needs container parsing).
int? extractTdlibDurationSeconds(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.duration;
  return null;
}

/// Extracts TDLib-provided width. Only MessageVideo has this.
int? extractTdlibWidth(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.width;
  return null;
}

/// Extracts TDLib-provided height. Only MessageVideo has this.
int? extractTdlibHeight(td.Message msg) {
  final c = msg.content;
  if (c is td.MessageVideo) return c.video.height;
  return null;
}
