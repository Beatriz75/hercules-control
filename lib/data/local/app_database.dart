import 'package:sqflite_common/sqflite.dart';

import 'app_database_platform.dart' as platform;
import 'database_seed.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get instance async {
    if (_database != null) {
      return _database!;
    }
    return open();
  }

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    final factory = platform.configureDatabaseFactory();
    final path = await platform.databasePath(factory);
    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await _createSchema(db);
          await _seedStores(db);
          await _createWeeklyReportsSchema(db);
          for (final statement in DatabaseSeed.statements) {
            await db.execute(statement);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createWeeklyReportsSchema(db);
          }
          if (oldVersion >= 2 && oldVersion < 3) {
            await db.execute(
              "ALTER TABLE weekly_reports ADD COLUMN store_code TEXT NOT NULL DEFAULT 'pideHoy';",
            );
          }
          if (oldVersion < 4) {
            await _createStoresSchema(db);
            await _seedStores(db);
          }
        },
      ),
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await _createStoresSchema(db);

    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        store_code TEXT NOT NULL,
        hire_date TEXT NOT NULL,
        termination_date TEXT,
        termination_reason TEXT,
        status TEXT NOT NULL,
        notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE employee_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        amount REAL NOT NULL,
        concept TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY(employee_id) REFERENCES employees(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE daily_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        review_date TEXT NOT NULL,
        employee_id INTEGER NOT NULL,
        store_code TEXT NOT NULL,
        supervisor_name TEXT NOT NULL,
        leads_reviewed INTEGER NOT NULL,
        avg_response_minutes REAL NOT NULL,
        customer_treatment_score REAL NOT NULL,
        faults_detected INTEGER NOT NULL DEFAULT 0,
        observations TEXT,
        score REAL NOT NULL,
        used_whatsapp INTEGER NOT NULL DEFAULT 0,
        traceability_risk INTEGER NOT NULL DEFAULT 0,
        additional_criteria TEXT,
        FOREIGN KEY(employee_id) REFERENCES employees(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        order_code TEXT NOT NULL,
        delivery_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        responsible TEXT NOT NULL,
        store_code TEXT NOT NULL,
        notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        order_code TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        validated_by TEXT NOT NULL,
        store_code TEXT NOT NULL,
        notes TEXT,
        line_id INTEGER,
        FOREIGN KEY(line_id) REFERENCES phone_lines(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        order_code TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        employee_id INTEGER,
        store_code TEXT NOT NULL,
        report_date TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        priority TEXT NOT NULL,
        owner TEXT NOT NULL,
        line_id INTEGER,
        traceability_risk INTEGER NOT NULL DEFAULT 0,
        external_channel INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(employee_id) REFERENCES employees(id),
        FOREIGN KEY(line_id) REFERENCES phone_lines(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE phone_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_number TEXT NOT NULL,
        alias TEXT NOT NULL,
        status TEXT NOT NULL,
        provider TEXT,
        created_at TEXT NOT NULL,
        notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE line_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        line_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        assigned_at TEXT NOT NULL,
        removed_at TEXT,
        status TEXT NOT NULL,
        FOREIGN KEY(line_id) REFERENCES phone_lines(id),
        FOREIGN KEY(employee_id) REFERENCES employees(id)
      );
    ''');
  }

  Future<void> _createStoresSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        code TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');
  }

  Future<void> _seedStores(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('stores', {
      'code': 'pideHoy',
      'label': 'Pide Hoy',
      'active': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('stores', {
      'code': 'mexiOfertas',
      'label': 'MexiOfertas',
      'active': 1,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _createWeeklyReportsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        store_code TEXT NOT NULL DEFAULT 'pideHoy',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        closed_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_report_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        report_date TEXT NOT NULL,
        delivered_total INTEGER NOT NULL DEFAULT 0,
        paid_delivered INTEGER NOT NULL DEFAULT 0,
        paid_level3 INTEGER NOT NULL DEFAULT 0,
        reports INTEGER NOT NULL DEFAULT 0,
        returns INTEGER NOT NULL DEFAULT 0,
        debtors INTEGER NOT NULL DEFAULT 0,
        ali_debtors INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(report_id) REFERENCES weekly_reports(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_report_custom_criteria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY(report_id) REFERENCES weekly_reports(id)
      );
    ''');
  }
}
