export 'db_platform_init_stub.dart'
    if (dart.library.html) 'db_platform_init_web.dart'
    if (dart.library.io) 'db_platform_init_io.dart';
