import 'dart:typed_data';
import '../video_metadata.dart';

class MkvParser {
  static (int value, int bytesRead)? readVInt(Uint8List data, int offset) {
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

  static (int value, int bytesRead)? readId(Uint8List data, int offset) {
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
  
  static int? readUint(Uint8List data, int offset, int size) {
    if (offset + size > data.length) return null;
    int value = 0;
    for (int i = 0; i < size; i++) {
      value = (value << 8) | data[offset + i];
    }
    return value;
  }

  static double? readFloat(Uint8List data, int offset, int size) {
    if (offset + size > data.length) return null;
    if (size == 4) {
      return ByteData.view(data.buffer, data.offsetInBytes + offset).getFloat32(0);
    } else if (size == 8) {
      return ByteData.view(data.buffer, data.offsetInBytes + offset).getFloat64(0);
    }
    return null;
  }

  static String? readString(Uint8List data, int offset, int size) {
    if (offset + size > data.length) return null;
    return String.fromCharCodes(data.sublist(offset, offset + size)).replaceAll('\x00', '');
  }

  static Future<VideoMetadata?> parse(Uint8List data) async {
    try {
      int offset = 0;
      int? durationMillis;
      int? width;
      int? height;
      String? codecHint;

      int timecodeScale = 1000000;
      double? durationFloat;

      bool inSegment = false;
      int segmentEnd = data.length;

      while (offset < data.length) {
        var idRes = readId(data, offset);
        if (idRes == null) break;
        int id = idRes.$1;
        offset += idRes.$2;
        
        var sizeRes = readVInt(data, offset);
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
            while (offset < infoEnd) {
              var subIdRes = readId(data, offset);
              if (subIdRes == null) break;
              int subId = subIdRes.$1;
              offset += subIdRes.$2;
              var subSizeRes = readVInt(data, offset);
              if (subSizeRes == null) break;
              int subSize = subSizeRes.$1;
              offset += subSizeRes.$2;
              
              if (subId == 0x2AD7B1) {
                timecodeScale = readUint(data, offset, subSize) ?? timecodeScale;
                offset += subSize;
              } else if (subId == 0x4489) {
                durationFloat = readFloat(data, offset, subSize);
                offset += subSize;
              } else {
                offset += subSize;
              }
            }
          } else if (id == 0x1654AE6B) {
            int tracksEnd = (size == -1) ? segmentEnd : offset + size;
            while (offset < tracksEnd) {
              var subIdRes = readId(data, offset);
              if (subIdRes == null) break;
              int subId = subIdRes.$1;
              offset += subIdRes.$2;
              var subSizeRes = readVInt(data, offset);
              if (subSizeRes == null) break;
              int subSize = subSizeRes.$1;
              offset += subSizeRes.$2;

              if (subId == 0xAE) {
                int entryEnd = (subSize == -1) ? tracksEnd : offset + subSize;
                bool isVideo = false;
                int? w, h;
                String? cHint;

                while (offset < entryEnd) {
                  var eIdRes = readId(data, offset);
                  if (eIdRes == null) break;
                  int eId = eIdRes.$1;
                  offset += eIdRes.$2;
                  var eSizeRes = readVInt(data, offset);
                  if (eSizeRes == null) break;
                  int eSize = eSizeRes.$1;
                  offset += eSizeRes.$2;

                  if (eId == 0x83) {
                    int tType = readUint(data, offset, eSize) ?? 0;
                    if (tType == 1) isVideo = true;
                    offset += eSize;
                  } else if (eId == 0x86) {
                    String codecStr = readString(data, offset, eSize) ?? '';
                    if (codecStr.contains('AVC')) {
                      cHint = 'h264';
                    } else if (codecStr.contains('HEVC')) {
                      cHint = 'hevc';
                    } else if (codecStr.contains('VP9')) {
                      cHint = 'vp9';
                    } else if (codecStr.contains('AV1')) {
                      cHint = 'av1';
                    } else {
                      cHint = codecStr;
                    }
                    offset += eSize;
                  } else if (eId == 0xE0) {
                    int videoEnd = (eSize == -1) ? entryEnd : offset + eSize;
                    if (videoEnd > data.length) videoEnd = data.length;

                    while (offset < videoEnd) {
                      var vIdRes = readId(data, offset);
                      if (vIdRes == null) break;
                      int vId = vIdRes.$1;
                      offset += vIdRes.$2;
                      
                      var vSizeRes = readVInt(data, offset);
                      if (vSizeRes == null) break;
                      int vSize = vSizeRes.$1;
                      offset += vSizeRes.$2;

                      if (vId == 0xB0) { // PixelWidth
                        w = readUint(data, offset, vSize);
                        offset += vSize;
                      } else if (vId == 0xBA) { // PixelHeight
                        h = readUint(data, offset, vSize);
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
                  codecHint = cHint;
                  break; // Found video track
                }
              } else {
                offset += subSize;
              }
            }
          } else if (id == 0x1F43B675) { // Cluster - stop parsing tracks and info
            break;
          } else {
            if (size != -1) {
              offset += size;
            } else {
              break;
            }
          }
        } else {
          // If not in Segment, and it's not EBML header (0x1A45DFA3), just skip
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
          codecHint: codecHint,
        );
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
