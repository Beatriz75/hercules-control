import 'package:sqflite_common/sqflite.dart';

import 'app_database_platform_io.dart'
    if (dart.library.html) 'app_database_platform_web.dart'
    as platform;

DatabaseFactory configureDatabaseFactory() =>
    platform.configureDatabaseFactory();

Future<String> databasePath(DatabaseFactory factory) =>
    platform.databasePath(factory);
