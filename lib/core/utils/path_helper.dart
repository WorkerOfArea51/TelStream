import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> getAppDirectory() async {
  if (Platform.isWindows) {
    return await getApplicationSupportDirectory();
  }
  return await getApplicationDocumentsDirectory();
}
