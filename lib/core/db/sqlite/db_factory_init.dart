import 'db_factory_init_stub.dart'
    if (dart.library.io) 'db_factory_init_io.dart'
    if (dart.library.js_interop) 'db_factory_init_web.dart'
    if (dart.library.html) 'db_factory_init_web.dart';

void initializeDatabaseFactory() => initDbFactory();
