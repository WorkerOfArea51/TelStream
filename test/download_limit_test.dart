import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/services/download_service.dart';

class TestDownloadController extends DownloadController {
  @override
  Map<int, DownloadTask> build() {
    return {};
  }
}

void main() {
  group('Download Speed Limit Parsing Tests', () {
    late TestDownloadController controller;

    setUp(() {
      controller = TestDownloadController();
    });

    test('parseSpeedLimitForTesting handles Unlimited correctly', () {
      expect(controller.parseSpeedLimitForTesting('Unlimited'), isNull);
    });

    test('parseSpeedLimitForTesting parses KB/s limits correctly', () {
      expect(controller.parseSpeedLimitForTesting('50 KB/s'), 50 * 1024);
      expect(controller.parseSpeedLimitForTesting('500 KB/s'), 500 * 1024);
      expect(controller.parseSpeedLimitForTesting('1024 KB/s'), 1024 * 1024);
    });

    test('parseSpeedLimitForTesting parses MB/s limits correctly', () {
      expect(controller.parseSpeedLimitForTesting('1 MB/s'), 1 * 1024 * 1024);
      expect(controller.parseSpeedLimitForTesting('5 MB/s'), 5 * 1024 * 1024);
      expect(controller.parseSpeedLimitForTesting('10 MB/s'), 10 * 1024 * 1024);
    });

    test('parseSpeedLimitForTesting returns null for invalid formats', () {
      expect(controller.parseSpeedLimitForTesting('invalid'), isNull);
      expect(controller.parseSpeedLimitForTesting('50KB'), isNull);
      expect(controller.parseSpeedLimitForTesting('50 GB/s'), isNull);
    });
  });
}
