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
