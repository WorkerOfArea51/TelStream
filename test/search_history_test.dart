import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telstream/services/storage_service.dart';

void main() {
  group('Search History Tests', () {
    late StorageService storageService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
      await storageService.saveSearchHistory('test_category', []);
    });

    test('getSearchHistory returns empty list initially', () {
      expect(storageService.getSearchHistory('test_category'), isEmpty);
    });

    test('saveSearchHistory saves and limits to 10 queries', () async {
      final queries = List.generate(15, (index) => 'query_$index');
      await storageService.saveSearchHistory('test_category', queries);

      final retrieved = storageService.getSearchHistory('test_category');
      expect(retrieved.length, 10);
      expect(retrieved.first, 'query_0');
      expect(retrieved.last, 'query_9');
    });

    test('saveSearchHistory overwrite works', () async {
      await storageService.saveSearchHistory('test_category', ['apple', 'banana']);
      expect(storageService.getSearchHistory('test_category'), ['apple', 'banana']);

      await storageService.saveSearchHistory('test_category', ['cherry']);
      expect(storageService.getSearchHistory('test_category'), ['cherry']);
    });
  });
}
