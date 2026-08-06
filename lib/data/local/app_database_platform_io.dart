import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory configureDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return databaseFactoryFfi;
}

Future<String> databasePath(DatabaseFactory factory) async {
  final root = await factory.getDatabasesPath();
  await Directory(root).create(recursive: true);
  return p.join(root, 'hercules_control.db');
}
