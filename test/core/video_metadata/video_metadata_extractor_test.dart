import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/core/video_metadata/video_metadata.dart';
import 'package:telstream/core/video_metadata/video_metadata_extractor.dart';
import 'package:telstream/core/video_metadata/parsers/mp4_parser.dart';

void main() {
  group('VideoMetadataExtractor', () {
    test('Garbage bytes -> returns null, no throw', () async {
      final garbage = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      final res = await VideoMetadataExtractor.extractFromPrefix(
        prefix: garbage,
        mimeType: 'video/mp4',
        fileName: 'test.mp4',
      );
      expect(res, isNull);
    });

    test('Truncated prefix (1 KB only) -> returns null, no throw', () async {
      final truncated = Uint8List(1024); // all zeros
      final res = await VideoMetadataExtractor.extractFromPrefix(
        prefix: truncated,
        mimeType: 'video/mp4',
        fileName: 'test.mp4',
      );
      expect(res, isNull);
    });

    // Mock MP4 parsing test
    test('MP4 parser with basic moov structure', () async {
      // Very basic mock of an MP4 moov box
      final builder = BytesBuilder();
      
      // ftyp box
      builder.add([0,0,0,16, 102,116,121,112, 109,112,52,50, 0,0,0,0]);
      
      // moov box
      final moovBuilder = BytesBuilder();
      
      // mvhd box
      final mvhdBuilder = BytesBuilder();
      mvhdBuilder.add([0,0,0,108, 109,118,104,100]); // size, 'mvhd'
      mvhdBuilder.add(List.filled(4, 0)); // version 0, flags
      mvhdBuilder.add(List.filled(4, 0)); // creation
      mvhdBuilder.add(List.filled(4, 0)); // mod
      mvhdBuilder.add([0,0,3,232]); // timescale: 1000
      mvhdBuilder.add([0,0,7,208]); // duration: 2000
      mvhdBuilder.add(List.filled(80, 0)); // rest
      moovBuilder.add(mvhdBuilder.toBytes());
      
      // trak box
      final trakBuilder = BytesBuilder();
      
      // tkhd box
      final tkhdBuilder = BytesBuilder();
      tkhdBuilder.add([0,0,0,92, 116,107,104,100]); // size, 'tkhd'
      tkhdBuilder.add(List.filled(76, 0));
      tkhdBuilder.add([3,0,0,0]); // width 768.0 (768 << 16)
      tkhdBuilder.add([1,224,0,0]); // height 480.0 (480 << 16)
      trakBuilder.add(tkhdBuilder.toBytes());
      
      // mdia box
      final mdiaBuilder = BytesBuilder();
      
      // hdlr box
      final hdlrBuilder = BytesBuilder();
      hdlrBuilder.add([0,0,0,32, 104,100,108,114]); // size, 'hdlr'
      hdlrBuilder.add(List.filled(8, 0));
      hdlrBuilder.add([118,105,100,101]); // 'vide'
      hdlrBuilder.add(List.filled(12, 0));
      mdiaBuilder.add(hdlrBuilder.toBytes());
      
      // minf box
      final minfBuilder = BytesBuilder();
      
      // stbl box
      final stblBuilder = BytesBuilder();
      
      // stsd box
      final stsdBuilder = BytesBuilder();
      stsdBuilder.add([0,0,0,32, 115,116,115,100]); // size, 'stsd'
      stsdBuilder.add(List.filled(4, 0));
      stsdBuilder.add([0,0,0,1]); // entry count
      
      stsdBuilder.add([0,0,0,16, 97,118,99,49]); // size, 'avc1'
      stsdBuilder.add(List.filled(8, 0));
      stblBuilder.add(stsdBuilder.toBytes());
      
      final stblData = stblBuilder.toBytes();
      final stblHeader = Uint8List(8);
      ByteData.view(stblHeader.buffer).setUint32(0, stblData.length + 8);
      stblHeader.setRange(4, 8, [115,116,98,108]); // 'stbl'
      minfBuilder.add(stblHeader);
      minfBuilder.add(stblData);
      
      final minfData = minfBuilder.toBytes();
      final minfHeader = Uint8List(8);
      ByteData.view(minfHeader.buffer).setUint32(0, minfData.length + 8);
      minfHeader.setRange(4, 8, [109,105,110,102]); // 'minf'
      mdiaBuilder.add(minfHeader);
      mdiaBuilder.add(minfData);

      final mdiaData = mdiaBuilder.toBytes();
      final mdiaHeader = Uint8List(8);
      ByteData.view(mdiaHeader.buffer).setUint32(0, mdiaData.length + 8);
      mdiaHeader.setRange(4, 8, [109,100,105,97]); // 'mdia'
      trakBuilder.add(mdiaHeader);
      trakBuilder.add(mdiaData);
      
      final trakData = trakBuilder.toBytes();
      final trakHeader = Uint8List(8);
      ByteData.view(trakHeader.buffer).setUint32(0, trakData.length + 8);
      trakHeader.setRange(4, 8, [116,114,97,107]); // 'trak'
      moovBuilder.add(trakHeader);
      moovBuilder.add(trakData);
      
      final moovData = moovBuilder.toBytes();
      final moovHeader = Uint8List(8);
      ByteData.view(moovHeader.buffer).setUint32(0, moovData.length + 8);
      moovHeader.setRange(4, 8, [109,111,111,118]); // 'moov'
      builder.add(moovHeader);
      builder.add(moovData);
      
      final res = await Mp4Parser.parse(builder.toBytes());
      expect(res, isNotNull);
      expect(res!.width, 768);
      expect(res.height, 480);
      expect(res.durationMillis, 2000);
      expect(res.container, VideoContainer.mp4);
      expect(res.codecHint, 'h264');
    });
  });
}
