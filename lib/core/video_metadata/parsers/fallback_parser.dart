import 'dart:typed_data';
import '../video_metadata.dart';

class FallbackParser {
  /// Last-resort parser. Detects container type from magic bytes and routes
  /// to the appropriate parser, even when the file extension is unknown or
  /// misleading (e.g., `.mkv.mp4`, `.video`, no extension).
  ///
  /// Returns null only if the data doesn't match any known container format.
  static Future<VideoMetadata?> parse(Uint8List data) async {
    if (data.length < 12) return null;

    // MP4/MOV/M4V: starts with ftyp box at offset 4.
    // Box layout: [4-byte size][4-byte type 'ftyp'][major brand][minor version]
    if (data[4] == 0x66 && // 'f'
        data[5] == 0x74 && // 't'
        data[6] == 0x79 && // 'y'
        data[7] == 0x70) { // 'p'
      // It's an MP4-family file. Use Mp4Parser.
      try {
        return await _parseMp4(data);
      } catch (_) {
        // fall through to other detections
      }
    }

    // MKV/WebM: starts with EBML header.
    // EBML magic: 0x1A 0x45 0xDF 0xA3
    if (data[0] == 0x1A &&
        data[1] == 0x45 &&
        data[2] == 0xDF &&
        data[3] == 0xA3) {
      // It's an MKV/WebM file. Use MkvParser.
      try {
        return await _parseMkv(data);
      } catch (_) {
        // fall through
      }
    }

    // Could not detect container from magic bytes.
    return null;
  }

  static Future<VideoMetadata?> _parseMp4(Uint8List data) async {
    // Inline MP4 parse — avoid circular import with Mp4Parser.
    // We only do a minimal moov-walk here. The Mp4Parser is the canonical
    // implementation; this is a fallback for when the file extension doesn't
    // route to Mp4Parser.
    try {
      int offset = 0;
      bool foundMoov = false;
      while (offset < data.length - 8) {
        final view = ByteData.view(data.buffer, data.offsetInBytes + offset);
        int size = view.getUint32(0);
        String type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

        int headerSize = 8;
        if (size == 1) {
          if (offset + 16 > data.length) break;
          size = view.getUint64(8);
          headerSize = 16;
        } else if (size == 0) {
          size = data.length - offset;
        }

        if (offset + headerSize > data.length) break;

        if (type == 'moov') {
          foundMoov = true;
          final moovData = data.sublist(
            offset + headerSize,
            (offset + size <= data.length) ? offset + size : data.length,
          );
          return _parseMoovMinimal(moovData);
        }

        if (offset + size <= data.length) {
          offset += size;
        } else {
          break;
        }
      }
      if (!foundMoov) return null;
    } catch (_) {}
    return null;
  }

  static VideoMetadata? _parseMoovMinimal(Uint8List moov) {
    int offset = 0;
    int? durationMillis;
    int? width;
    int? height;

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

      if (offset + size > moov.length) break;

      if (type == 'mvhd') {
        if (size >= headerSize + 24) {
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
        final trackInfo = _parseTrakMinimal(trakData);
        if (trackInfo != null && trackInfo['isVideo'] == true) {
          width = trackInfo['width'] as int?;
          height = trackInfo['height'] as int?;
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
      );
    }
    return null;
  }

  static Map<String, dynamic>? _parseTrakMinimal(Uint8List trak) {
    int offset = 0;
    int? width;
    int? height;
    bool isVideo = false;

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
        if (_isVideoTrack(mdiaData)) {
          isVideo = true;
        }
      }

      offset += size;
    }

    return {
      'width': width,
      'height': height,
      'isVideo': isVideo,
    };
  }

  static bool _isVideoTrack(Uint8List mdia) {
    int offset = 0;
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
          String handlerType = String.fromCharCodes(
            mdia.sublist(offset + headerSize + 8, offset + headerSize + 12),
          );
          if (handlerType == 'vide') return true;
        }
      }
      offset += size;
    }
    return false;
  }

  static Future<VideoMetadata?> _parseMkv(Uint8List data) async {
    // Inline MKV parse — avoid circular import with MkvParser.
    // This is a minimal implementation that extracts width/height/duration.
    try {
      int offset = 0;
      int? durationMillis;
      int? width;
      int? height;
      int timecodeScale = 1000000;
      double? durationFloat;
      bool inSegment = false;
      int segmentEnd = data.length;

      int iterations = 0;
      const int maxIterations = 100000;

      while (offset < data.length && iterations < maxIterations) {
        iterations++;
        var idRes = _readId(data, offset);
        if (idRes == null) break;
        int id = idRes.$1;
        offset += idRes.$2;
        var sizeRes = _readVInt(data, offset);
        if (sizeRes == null) break;
        int size = sizeRes.$1;
        offset += sizeRes.$2;

        if (id == 0x18538067) {
          inSegment = true;
          if (size != -1) {
            segmentEnd = offset + size;
            if (segmentEnd > data.length) segmentEnd = data.length;
          }
          continue;
        }

        if (inSegment) {
          if (id == 0x1549A966) {
            int infoEnd = (size == -1) ? segmentEnd : offset + size;
            if (infoEnd > data.length) infoEnd = data.length;
            while (offset < infoEnd) {
              var subIdRes = _readId(data, offset);
              if (subIdRes == null) break;
              int subId = subIdRes.$1;
              offset += subIdRes.$2;
              var subSizeRes = _readVInt(data, offset);
              if (subSizeRes == null) break;
              int subSize = subSizeRes.$1;
              offset += subSizeRes.$2;
              if (subId == 0x2AD7B1) {
                timecodeScale = _readUint(data, offset, subSize) ?? timecodeScale;
                offset += subSize;
              } else if (subId == 0x4489) {
                durationFloat = _readFloat(data, offset, subSize);
                offset += subSize;
              } else {
                offset += subSize;
              }
            }
          } else if (id == 0x1654AE6B) {
            int tracksEnd = (size == -1) ? segmentEnd : offset + size;
            if (tracksEnd > data.length) tracksEnd = data.length;
            while (offset < tracksEnd) {
              var subIdRes = _readId(data, offset);
              if (subIdRes == null) break;
              int subId = subIdRes.$1;
              offset += subIdRes.$2;
              var subSizeRes = _readVInt(data, offset);
              if (subSizeRes == null) break;
              int subSize = subSizeRes.$1;
              offset += subSizeRes.$2;
              if (subId == 0xAE) {
                int entryEnd = (subSize == -1) ? tracksEnd : offset + subSize;
                if (entryEnd > data.length) entryEnd = data.length;
                bool isVideo = false;
                int? w, h;
                while (offset < entryEnd) {
                  var eIdRes = _readId(data, offset);
                  if (eIdRes == null) break;
                  int eId = eIdRes.$1;
                  offset += eIdRes.$2;
                  var eSizeRes = _readVInt(data, offset);
                  if (eSizeRes == null) break;
                  int eSize = eSizeRes.$1;
                  offset += eSizeRes.$2;
                  if (eId == 0x83) {
                    int tType = _readUint(data, offset, eSize) ?? 0;
                    if (tType == 1) isVideo = true;
                    offset += eSize;
                  } else if (eId == 0xE0) {
                    int videoEnd = (eSize == -1) ? entryEnd : offset + eSize;
                    if (videoEnd > data.length) videoEnd = data.length;
                    while (offset < videoEnd) {
                      var vIdRes = _readId(data, offset);
                      if (vIdRes == null) break;
                      int vId = vIdRes.$1;
                      offset += vIdRes.$2;
                      var vSizeRes = _readVInt(data, offset);
                      if (vSizeRes == null) break;
                      int vSize = vSizeRes.$1;
                      offset += vSizeRes.$2;
                      if (vId == 0xB0) {
                        w = _readUint(data, offset, vSize);
                        offset += vSize;
                      } else if (vId == 0xBA) {
                        h = _readUint(data, offset, vSize);
                        offset += vSize;
                      } else {
                        offset += vSize;
                      }
                    }
                  } else {
                    offset += eSize;
                  }
                }
                if (isVideo && w != null && h != null) {
                  width = w;
                  height = h;
                  break;
                }
              } else {
                offset += subSize;
              }
            }
          } else if (id == 0x1F43B675) {
            break;
          } else {
            if (size != -1) {
              offset += size;
            } else {
              break;
            }
          }
        } else {
          if (size != -1) {
            offset += size;
          } else {
            break;
          }
        }
      }

      if (durationFloat != null && durationFloat > 0) {
        durationMillis = (durationFloat * timecodeScale / 1000000.0).round();
      }
      if (width != null && height != null) {
        return VideoMetadata(
          width: width,
          height: height,
          durationMillis: durationMillis ?? 0,
          container: VideoContainer.mkv,
        );
      }
    } catch (_) {}
    return null;
  }

  // Inline EBML readers (avoid circular import with MkvParser).
  static (int, int)? _readId(Uint8List data, int offset) {
    if (offset >= data.length) return null;
    int firstByte = data[offset];
    int numBytes = 1;
    int mask = 0x80;
    while (mask > 0 && (firstByte & mask) == 0) {
      numBytes++;
      mask >>= 1;
    }
    if (mask == 0 || numBytes > 4 || offset + numBytes > data.length) return null;
    int value = 0;
    for (int i = 0; i < numBytes; i++) {
      value = (value << 8) | data[offset + i];
    }
    return (value, numBytes);
  }

  static (int, int)? _readVInt(Uint8List data, int offset) {
    if (offset >= data.length) return null;
    int firstByte = data[offset];
    int numBytes = 1;
    int mask = 0x80;
    while (mask > 0 && (firstByte & mask) == 0) {
      numBytes++;
      mask >>= 1;
    }
    if (mask == 0 || offset + numBytes > data.length) return null;
    int value = firstByte & ~mask;
    for (int i = 1; i < numBytes; i++) {
      value = (value << 8) | data[offset + i];
    }
    int maxVal = (1 << (7 * numBytes)) - 1;
    if (value == maxVal) value = -1;
    return (value, numBytes);
  }

  static int? _readUint(Uint8List data, int offset, int size) {
    if (offset + size > data.length) return null;
    int value = 0;
    for (int i = 0; i < size; i++) {
      value = (value << 8) | data[offset + i];
    }
    return value;
  }

  static double? _readFloat(Uint8List data, int offset, int size) {
    if (offset + size > data.length) return null;
    if (size == 4) {
      return ByteData.view(data.buffer, data.offsetInBytes + offset).getFloat32(0);
    } else if (size == 8) {
      return ByteData.view(data.buffer, data.offsetInBytes + offset).getFloat64(0);
    }
    return null;
  }
}
