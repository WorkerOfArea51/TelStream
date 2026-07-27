import 'dart:typed_data';
import '../video_metadata.dart';

class MkvParser {
  static Future<VideoMetadata?> parse(Uint8List data) async {
    try {
      int offset = 0;

      int? _readVInt(bool isSize) {
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
        offset += numBytes;
        
        if (isSize) {
          // If all bits are 1, it's an unknown size. Return -1 or something, but we assume it's bounded for now.
          int maxVal = (1 << (7 * numBytes)) - 1;
          if (value == maxVal) return -1; // unknown size
        }
        return value;
      }

      int? _readId() {
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
        offset += numBytes;
        return value;
      }
      
      int? _readUint(int size) {
        if (offset + size > data.length) return null;
        int value = 0;
        for (int i = 0; i < size; i++) {
          value = (value << 8) | data[offset + i];
        }
        offset += size;
        return value;
      }

      double? _readFloat(int size) {
        if (offset + size > data.length) return null;
        double? value;
        if (size == 4) {
          value = ByteData.view(data.buffer, data.offsetInBytes + offset).getFloat32(0);
        } else if (size == 8) {
          value = ByteData.view(data.buffer, data.offsetInBytes + offset).getFloat64(0);
        }
        offset += size;
        return value;
      }

      String? _readString(int size) {
        if (offset + size > data.length) return null;
        String value = String.fromCharCodes(data.sublist(offset, offset + size)).replaceAll('\x00', '');
        offset += size;
        return value;
      }

      int? durationMillis;
      int? width;
      int? height;
      String? codecHint;

      int timecodeScale = 1000000; // default
      double? durationFloat;

      bool inSegment = false;
      int segmentEnd = data.length;

      while (offset < data.length) {
        int elementStart = offset;
        int? id = _readId();
        if (id == null) break;
        int? size = _readVInt(true);
        if (size == null) break;

        if (id == 0x18538067) { // Segment
          inSegment = true;
          if (size != -1) {
            segmentEnd = offset + size;
            if (segmentEnd > data.length) segmentEnd = data.length;
          }
          continue;
        }

        if (inSegment) {
          if (id == 0x1549A966) { // Info
            int infoEnd = (size == -1) ? segmentEnd : offset + size;
            if (infoEnd > data.length) infoEnd = data.length;
            
            while (offset < infoEnd) {
              int? subId = _readId();
              if (subId == null) break;
              int? subSize = _readVInt(true);
              if (subSize == null) break;
              
              if (subId == 0x2AD7B1) { // TimecodeScale
                timecodeScale = _readUint(subSize) ?? timecodeScale;
              } else if (subId == 0x4489) { // Duration
                durationFloat = _readFloat(subSize);
              } else {
                offset += subSize;
              }
            }
          } else if (id == 0x1654AE6B) { // Tracks
            int tracksEnd = (size == -1) ? segmentEnd : offset + size;
            if (tracksEnd > data.length) tracksEnd = data.length;

            while (offset < tracksEnd) {
              int? subId = _readId();
              if (subId == null) break;
              int? subSize = _readVInt(true);
              if (subSize == null) break;

              if (subId == 0xAE) { // TrackEntry
                int entryEnd = (subSize == -1) ? tracksEnd : offset + subSize;
                if (entryEnd > data.length) entryEnd = data.length;

                bool isVideo = false;
                int? w, h;
                String? cHint;

                while (offset < entryEnd) {
                  int? eId = _readId();
                  if (eId == null) break;
                  int? eSize = _readVInt(true);
                  if (eSize == null) break;

                  if (eId == 0x83) { // TrackType
                    int tType = _readUint(eSize) ?? 0;
                    if (tType == 1) isVideo = true;
                  } else if (eId == 0x86) { // CodecID
                    String codecStr = _readString(eSize) ?? '';
                    if (codecStr.contains('AVC')) cHint = 'h264';
                    else if (codecStr.contains('HEVC')) cHint = 'hevc';
                    else if (codecStr.contains('VP9')) cHint = 'vp9';
                    else if (codecStr.contains('AV1')) cHint = 'av1';
                    else cHint = codecStr;
                  } else if (eId == 0xE0) { // Video
                    int videoEnd = (eSize == -1) ? entryEnd : offset + eSize;
                    if (videoEnd > data.length) videoEnd = data.length;

                    while (offset < videoEnd) {
                      int? vId = _readId();
                      if (vId == null) break;
                      int? vSize = _readVInt(true);
                      if (vSize == null) break;

                      if (vId == 0xB0) { // PixelWidth
                        w = _readUint(vSize);
                      } else if (vId == 0xBA) { // PixelHeight
                        h = _readUint(vSize);
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

      if (width != null && height != null && durationMillis != null) {
        return VideoMetadata(
          width: width,
          height: height,
          durationMillis: durationMillis,
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
