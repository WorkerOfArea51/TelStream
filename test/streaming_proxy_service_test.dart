import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:telstream/services/tdlib_service.dart';
import 'package:telstream/services/streaming_proxy_service.dart';

class FakeTdlibService implements TdlibService {
  final StreamController<td.TdObject> _updatesController = StreamController<td.TdObject>.broadcast();

  @override
  Stream<td.TdObject> get updates => _updatesController.stream;

  final Map<int, td.File> _mockFiles = {};

  void setMockFile(td.File file) {
    _mockFiles[file.id] = file;
    _updatesController.add(td.UpdateFile(file: file));
  }

  @override
  Future<td.TdObject> sendAsync(td.TdFunction request) async {
    if (request is td.GetFile) {
      final file = _mockFiles[request.fileId];
      if (file != null) return file;
      return td.TdError(code: 404, message: 'File not found');
    }
    return const td.Ok();
  }

  @override
  void send(td.TdFunction request, {dynamic extra}) {
    // No-op for testing offset shifts
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

void main() {
  group('StreamingProxyService Tests', () {
    late FakeTdlibService fakeTdlibService;
    late StreamingProxyService proxyService;
    late Directory tempDir;
    late File mockVideoFile;
    const int mockFileId = 999;
    const String testData = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    setUp(() async {
      fakeTdlibService = FakeTdlibService();
      proxyService = StreamingProxyService(fakeTdlibService);
      await proxyService.start();

      // Create a temporary mock video file on disk
      tempDir = await Directory.systemTemp.createTemp('telstream_proxy_test');
      mockVideoFile = File('${tempDir.path}/test_video.mp4');
      await mockVideoFile.writeAsString(testData);
    });

    tearDown(() async {
      await proxyService.stop();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('serves fully completed local files directly', () async {
      // 1. Setup mock file as fully downloaded
      final completedFile = td.File(
        id: mockFileId,
        size: testData.length,
        expectedSize: testData.length,
        local: td.LocalFile(
          path: mockVideoFile.path,
          isDownloadingActive: false,
          isDownloadingCompleted: true, // triggers DirectCompleted streaming optimization
          downloadOffset: 0,
          downloadedPrefixSize: testData.length,
          downloadedSize: testData.length,
          canBeDownloaded: true,
          canBeDeleted: true,
        ),
        remote: td.RemoteFile(
          id: 'remote_999',
          uniqueId: 'uid_999',
          isUploadingActive: false,
          isUploadingCompleted: true,
          uploadedSize: testData.length,
        ),
      );
      fakeTdlibService.setMockFile(completedFile);

      // 2. Fetch the video file via the proxy local server
      final url = proxyService.getProxyUrl(mockFileId, fileName: 'test_video.mp4');
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      // 3. Verify response
      expect(response.statusCode, equals(HttpStatus.ok));
      expect(response.headers.value(HttpHeaders.contentTypeHeader), equals('video/mp4'));
      expect(response.headers.contentLength, equals(testData.length));

      final responseBody = await response.transform(const SystemEncoding().decoder).join();
      expect(responseBody, equals(testData));
    });

    test('supports Range HTTP requests for seeking', () async {
      // 1. Setup mock file
      final completedFile = td.File(
        id: mockFileId,
        size: testData.length,
        expectedSize: testData.length,
        local: td.LocalFile(
          path: mockVideoFile.path,
          isDownloadingActive: false,
          isDownloadingCompleted: true,
          downloadOffset: 0,
          downloadedPrefixSize: testData.length,
          downloadedSize: testData.length,
          canBeDownloaded: true,
          canBeDeleted: true,
        ),
        remote: td.RemoteFile(
          id: 'remote_999',
          uniqueId: 'uid_999',
          isUploadingActive: false,
          isUploadingCompleted: true,
          uploadedSize: testData.length,
        ),
      );
      fakeTdlibService.setMockFile(completedFile);

      // 2. Query range bytes 10-19
      final url = proxyService.getProxyUrl(mockFileId);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
      final response = await request.close();

      // 3. Verify status code 206 (Partial Content) and range header
      expect(response.statusCode, equals(HttpStatus.partialContent));
      expect(response.headers.value(HttpHeaders.contentRangeHeader), equals('bytes 10-19/${testData.length}'));
      expect(response.headers.contentLength, equals(10));

      final responseBody = await response.transform(const SystemEncoding().decoder).join();
      expect(responseBody, equals('ABCDEFGHIJ'));
    });
  });
}
