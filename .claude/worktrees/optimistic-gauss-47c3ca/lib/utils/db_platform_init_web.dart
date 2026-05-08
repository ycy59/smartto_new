import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> initDatabaseFactory() async {
  // SharedWorker 방식은 dev 환경에서 WASM 로딩 실패 가능성이 있어
  // 메인 스레드에서 직접 실행하는 방식 사용
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
