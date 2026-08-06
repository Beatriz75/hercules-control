import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
  return databaseFactoryFfiWeb;
}

Future<String> databasePath(DatabaseFactory factory) async =>
    'hercules_control.db';
