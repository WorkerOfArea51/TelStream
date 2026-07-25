import 'package:tdlib/td_api.dart' as td;

/// Extracts the poster thumbnail and minithumbnail from a Telegram [td.Message].
///
/// Handles three message content types:
///  * [td.MessagePhoto]     — channels that post a separate poster image with a caption.
///  * [td.MessageVideo]     — single-file channels where the video itself is the "poster".
///  * [td.MessageDocument]  — video files sent as documents (`.mkv`, `.mp4`, etc.).
///
/// Returns a record with both fields `null` if the message has no usable thumbnail
/// (e.g. an audio message, a text-only message, or a video whose thumbnail field
/// is genuinely absent on the Telegram side).
///
/// Usage:
/// ```dart
/// final poster = series.seasons.isNotEmpty ? series.seasons.first.posterMessage : null;
/// final extracted = extractPosterThumbnail(poster);
/// TdThumbnail(
///   file: extracted.file,
///   minithumbnail: extracted.minithumbnail,
///   ...
/// );
/// ```
({td.File? file, td.Minithumbnail? minithumbnail}) extractPosterThumbnail(td.Message? poster) {
  if (poster == null) return (file: null, minithumbnail: null);

  final content = poster.content;

  // 1. Photo poster — the "intended" code path for series with separate poster images.
  if (content is td.MessagePhoto) {
    final photo = content.photo;
    td.File? file;
    if (photo.sizes.isNotEmpty) {
      file = photo.sizes.last.photo;
    }
    return (file: file, minithumbnail: photo.minithumbnail);
  }

  // 2. Video — single-file channels where the video itself is the poster.
  //    Video.thumbnail is a Thumbnail? whose .photo is the td.File we want.
  //    Video.minithumbnail is a Minithumbnail? (base64 JPEG) for instant display.
  if (content is td.MessageVideo) {
    final video = content.video;
    return (file: video.thumbnail?.file, minithumbnail: video.minithumbnail);
  }

  // 3. Document — video files sent as documents (some channels do this to bypass
  //    Telegram's video compression). Document.thumbnail / Document.minithumbnail
  //    have the same shape as Video's.
  if (content is td.MessageDocument) {
    final doc = content.document;
    return (file: doc.thumbnail?.file, minithumbnail: doc.minithumbnail);
  }

  // 4. Anything else (text, audio, sticker, etc.) — no thumbnail available.
  return (file: null, minithumbnail: null);
}
