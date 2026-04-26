import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initDatabaseFactory() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // iOS, Android, macOS는 sqflite 기본 factory 사용 (별도 초기화 불필요)
}
