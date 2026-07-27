import 'dart:typed_data';
import '../video_metadata.dart';

class Mp4Parser {
  /// Scans [suffix] for the 4-byte 'moov' signature (0x6D6F6F76) and parses
  /// the moov box starting at that offset. Use this for moov-at-end MP4s where
  /// the prefix doesn't contain moov.
  /// 
  /// Returns null if no moov signature is found or parsing fails.
  static Future<VideoMetadata?> parseMoovFromSuffix(Uint8List suffix) async {
    try {
      // Scan for 'moov' (0x6D 0x6F 0x6F 0x76) at every offset.
      // The moov box's size field is the 4 bytes BEFORE the 'moov' type.
      // So when we find 'moov' at offset i, the box starts at i-4 and the
      // size is the uint32 at i-4.
      for (int i = 4; i <= suffix.length - 8; i++) {
        if (suffix[i] == 0x6D &&  // 'm'
            suffix[i + 1] == 0x6F &&  // 'o'
            suffix[i + 2] == 0x6F &&  // 'o'
            suffix[i + 3] == 0x76) {  // 'v'
          // Found 'moov' at offset i. The box starts at i-4 (size field).
          final boxStart = i - 4;
          final view = ByteData.view(suffix.buffer, suffix.offsetInBytes + boxStart);
          int size = view.getUint32(0);
          int headerSize = 8;
          if (size == 1) {
            // 64-bit size â€” read next 8 bytes after the type.
            if (boxStart + 16 > suffix.length) continue;  // truncated, try next match
            size = view.getUint64(8);
            headerSize = 16;
          } else if (size == 0) {
            // Box extends to EOF â€” use what we have.
            size = suffix.length - boxStart;
          }
          
          // Extract the moov box content (after the header).
          final moovEnd = (boxStart + size <= suffix.length) ? boxStart + size : suffix.length;
          final moovData = suffix.sublist(boxStart + headerSize, moovEnd);
          
          // Parse the moov box content.
          final result = _parseMoov(moovData);
          if (result != null) return result;
          // If _parseMoov returned null, the moov box was malformed â€” try next match.
        }
      }
    } catch (e) {
      // Ignore â€” return null
    }
    return null;
  }

  static Future<VideoMetadata?> parse(Uint8List data) async {
    bool foundFtyp = false;
    try {
      int offset = 0;
      
      while (offset < data.length - 8) {
        final view = ByteData.view(data.buffer, data.offsetInBytes + offset);
        int size = view.getUint32(0);
        String type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
        
        int headerSize = 8;
        if (size == 1) {
          if (offset + 16 > data.length) return null; // Truncated
          size = view.getUint64(8);
          headerSize = 16;
        } else if (size == 0) {
          // box extends to end of file
          size = data.length - offset;
        }
        
        if (offset + headerSize > data.length) return null;
        if (type == 'ftyp') foundFtyp = true;
        
        if (type == 'moov') {
          // Parse moov box
          final moovData = data.sublist(offset + headerSize, (offset + size <= data.length) ? offset + size : data.length);
          return _parseMoov(moovData);
        } else {
          // Skip box
          if (offset + size <= data.length) {
            offset += size;
          } else {
            // The current box extends past our prefix buffer. If we've seen
            // ftyp, the moov is almost certainly at the end of the file —
            // signal that to the caller via the typed exception so they can
            // fetch the suffix. Otherwise just return null (not an MP4).
            if (foundFtyp) {
              throw Exception('moov_not_found');
            }
            return null;
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('moov_not_found')) rethrow;
      // Ignore other errors parsing prefix
    }
    // If we walked every box in the prefix and saw ftyp but no moov, the moov
    // is at the end of the file. Signal that to the caller.
    if (foundFtyp) {
      throw Exception('moov_not_found');
    }
    return null;
  }

  static VideoMetadata? _parseMoov(Uint8List moov) {
    int offset = 0;
    int? durationMillis;
    int? width;
    int? height;
    String? codecHint;

    while (offset < moov.length - 8) {
      final view = ByteData.view(moov.buffer, moov.offsetInBytes + offset);
      int size = view.getUint32(0);
      String type = String.fromCharCodes(moov.sublist(offset + 4, offset + 8));

      int headerSize = 8;
      if (size == 1) {
        if (offset + 16 > moov.length) break;
        size = view.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = moov.length - offset;
      }

      if (offset + size > moov.length) break; // Truncated box

      if (type == 'mvhd') {
        if (size >= headerSize + 24) { // version + flags (4), creation (4/8), mod (4/8), timescale (4), duration (4/8)
          final v = ByteData.view(moov.buffer, moov.offsetInBytes + offset + headerSize);
          int version = v.getUint8(0);
          int timescale = 0;
          int duration = 0;
          
          if (version == 1) {
            if (size >= headerSize + 32) {
              timescale = v.getUint32(20);
              duration = v.getUint64(24);
            }
          } else {
            timescale = v.getUint32(12);
            duration = v.getUint32(16);
          }
          
          if (timescale > 0) {
            durationMillis = (duration * 1000) ~/ timescale;
          }
        }
      } else if (type == 'trak') {
        final trakData = moov.sublist(offset + headerSize, offset + size);
        final trackInfo = _parseTrak(trakData);
        if (trackInfo != null && trackInfo['isVideo'] == true) {
          width = trackInfo['width'] as int?;
          height = trackInfo['height'] as int?;
          codecHint = trackInfo['codec'] as String?;
        }
      }

      offset += size;
    }

    if (width != null && height != null) {
      return VideoMetadata(
        width: width,
        height: height,
        durationMillis: durationMillis ?? 0,
        container: VideoContainer.mp4,
        codecHint: codecHint,
      );
    }
    return null;
  }

  static Map<String, dynamic>? _parseTrak(Uint8List trak) {
    int offset = 0;
    int? width;
    int? height;
    bool isVideo = false;
    String? codecHint;

    while (offset < trak.length - 8) {
      final view = ByteData.view(trak.buffer, trak.offsetInBytes + offset);
      int size = view.getUint32(0);
      String type = String.fromCharCodes(trak.sublist(offset + 4, offset + 8));
      
      int headerSize = 8;
      if (size == 1) {
        if (offset + 16 > trak.length) break;
        size = view.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = trak.length - offset;
      }
      
      if (offset + size > trak.length) break;

      if (type == 'tkhd') {
        if (size >= headerSize + 84) {
          final v = ByteData.view(trak.buffer, trak.offsetInBytes + offset + headerSize);
          int version = v.getUint8(0);
          int wOffset = version == 1 ? 88 : 76;
          int hOffset = version == 1 ? 92 : 80;
          
          if (size >= headerSize + hOffset + 4) {
            int wFixed = v.getUint32(wOffset);
            int hFixed = v.getUint32(hOffset);
            
            int w = wFixed >> 16;
            int h = hFixed >> 16;
            
            if (w > 0 && h > 0) {
              width = w;
              height = h;
            }
          }
        }
      } else if (type == 'mdia') {
        final mdiaData = trak.sublist(offset + headerSize, offset + size);
        final mdiaInfo = _parseMdia(mdiaData);
        if (mdiaInfo != null) {
          if (mdiaInfo['isVideo'] == true) isVideo = true;
          if (mdiaInfo['codec'] != null) codecHint = mdiaInfo['codec'] as String?;
        }
      }

      offset += size;
    }

    return {
      'width': width,
      'height': height,
      'isVideo': isVideo,
      'codec': codecHint,
    };
  }

  static Map<String, dynamic>? _parseMdia(Uint8List mdia) {
    int offset = 0;
    bool isVideo = false;
    String? codecHint;

    while (offset < mdia.length - 8) {
      final view = ByteData.view(mdia.buffer, mdia.offsetInBytes + offset);
      int size = view.getUint32(0);
      String type = String.fromCharCodes(mdia.sublist(offset + 4, offset + 8));
      
      int headerSize = 8;
      if (size == 1) {
        if (offset + 16 > mdia.length) break;
        size = view.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = mdia.length - offset;
      }
      
      if (offset + size > mdia.length) break;

      if (type == 'hdlr') {
        if (size >= headerSize + 12) {
          String handlerType = String.fromCharCodes(mdia.sublist(offset + headerSize + 8, offset + headerSize + 12));
          if (handlerType == 'vide') {
            isVideo = true;
          }
        }
      } else if (type == 'minf') {
        final minfData = mdia.sublist(offset + headerSize, offset + size);
        final minfInfo = _parseMinf(minfData);
        if (minfInfo != null) {
          if (minfInfo['codec'] != null) codecHint = minfInfo['codec'] as String?;
        }
      }

      offset += size;
    }

    return {
      'isVideo': isVideo,
      'codec': codecHint,
    };
  }
  
  static Map<String, dynamic>? _parseMinf(Uint8List minf) {
    int offset = 0;
    String? codecHint;

    while (offset < minf.length - 8) {
      final view = ByteData.view(minf.buffer, minf.offsetInBytes + offset);
      int size = view.getUint32(0);
      String type = String.fromCharCodes(minf.sublist(offset + 4, offset + 8));
      
      int headerSize = 8;
      if (size == 1) {
        if (offset + 16 > minf.length) break;
        size = view.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = minf.length - offset;
      }
      
      if (offset + size > minf.length) break;

      if (type == 'stbl') {
        final stblData = minf.sublist(offset + headerSize, offset + size);
        final stblInfo = _parseStbl(stblData);
        if (stblInfo != null) {
          if (stblInfo['codec'] != null) codecHint = stblInfo['codec'] as String?;
        }
      }

      offset += size;
    }

    return {
      'codec': codecHint,
    };
  }
  
  static Map<String, dynamic>? _parseStbl(Uint8List stbl) {
    int offset = 0;
    String? codecHint;

    while (offset < stbl.length - 8) {
      final view = ByteData.view(stbl.buffer, stbl.offsetInBytes + offset);
      int size = view.getUint32(0);
      String type = String.fromCharCodes(stbl.sublist(offset + 4, offset + 8));
      
      int headerSize = 8;
      if (size == 1) {
        if (offset + 16 > stbl.length) break;
        size = view.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = stbl.length - offset;
      }
      
      if (offset + size > stbl.length) break;

      if (type == 'stsd') {
        if (size >= headerSize + 8) {
          final v = ByteData.view(stbl.buffer, stbl.offsetInBytes + offset + headerSize);
          int entryCount = v.getUint32(4);
          if (entryCount > 0 && size >= headerSize + 16) {
             // Read the first sample entry
             String sampleType = String.fromCharCodes(stbl.sublist(offset + headerSize + 12, offset + headerSize + 16));
            if (sampleType == 'avc1') {
              codecHint = 'h264';
            } else if (sampleType == 'hev1' || sampleType == 'hvc1') {
              codecHint = 'hevc';
            } else if (sampleType == 'vp09') {
              codecHint = 'vp9';
            } else if (sampleType == 'av01') {
              codecHint = 'av1';
            } else {
              codecHint = sampleType;
            }
          }
        }
      }

      offset += size;
    }

    return {
      'codec': codecHint,
    };
  }
}
