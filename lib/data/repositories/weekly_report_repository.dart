import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/weekly_custom_criterion.dart';
import 'package:hercules_control/domain/entities/weekly_report.dart';
import 'package:hercules_control/domain/entities/weekly_report_bundle.dart';
import 'package:hercules_control/domain/entities/weekly_report_day.dart';
import 'package:hercules_control/domain/value_objects/store_type.dart';

class WeeklyReportRepository {
  WeeklyReportRepository(this._database);

  final AppDatabase _database;

  Future<List<WeeklyReportBundle>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query(
      'weekly_reports',
      orderBy: 'start_date DESC, store_code ASC',
    );

    final bundles = <WeeklyReportBundle>[];
    for (final row in rows) {
      bundles.add(await _bundleFromReport(WeeklyReport.fromMap(row)));
    }
    return bundles;
  }

  Future<List<WeeklyReportBundle>> fetchRecent({int limit = 4}) async {
    final reports = await fetchAll();
    return reports.take(limit).toList();
  }

  Future<List<StoreType>> fetchStores() async {
    final db = await _database.instance;
    final rows = await db.query(
      'stores',
      where: 'active = ?',
      whereArgs: [1],
      orderBy: 'label ASC',
    );
    if (rows.isEmpty) {
      return StoreType.values;
    }
    return rows.map((row) {
      return StoreType(row['code'] as String, row['label'] as String);
    }).toList();
  }

  Future<StoreType> addStore(String label) async {
    final db = await _database.instance;
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) {
      throw ArgumentError('El nombre de la tienda no puede estar vacio.');
    }
    final store = StoreType(cleanLabel, cleanLabel);
    await db.insert('stores', {
      'code': store.name,
      'label': store.label,
      'active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return store;
  }

  Future<WeeklyReportBundle> createReport({
    required DateTime startDate,
    required StoreType store,
    String notes = '',
  }) async {
    final db = await _database.instance;
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDate = normalizedStart.add(const Duration(days: 6));
    final now = DateTime.now();
    final reportId = await db.insert('weekly_reports', {
      'title':
          '${store.label} - Reporte ${_dateLabel(normalizedStart)} - ${_dateLabel(endDate)}',
      'store_code': store.name,
      'start_date': normalizedStart.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'borrador',
      'notes': notes,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'closed_at': null,
    });

    for (var i = 0; i < 7; i++) {
      final day = WeeklyReportDay.empty(
        reportId: reportId,
        reportDate: normalizedStart.add(Duration(days: i)),
      );
      await db.insert('weekly_report_days', day.toMap()..remove('id'));
    }

    return fetchById(reportId);
  }

  Future<WeeklyReportBundle> fetchById(int reportId) async {
    final db = await _database.instance;
    final rows = await db.query(
      'weekly_reports',
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Reporte semanal no encontrado: $reportId');
    }
    return _bundleFromReport(WeeklyReport.fromMap(rows.first));
  }

  Future<void> saveDays(int reportId, List<WeeklyReportDay> days) async {
    final db = await _database.instance;
    await db.transaction((txn) async {
      for (final day in days) {
        final map = day.toMap()..remove('id');
        await txn.update(
          'weekly_report_days',
          map,
          where: 'id = ?',
          whereArgs: [day.id],
        );
      }
      await txn.update(
        'weekly_reports',
        {
          'status': 'borrador',
          'updated_at': DateTime.now().toIso8601String(),
          'closed_at': null,
        },
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });
  }

  Future<void> closeReport(int reportId) async {
    final report = await fetchById(reportId);
    if (!report.isBalanced) {
      throw StateError(
        'Aun hay una diferencia de ${report.difference} registros.',
      );
    }

    final db = await _database.instance;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'weekly_reports',
      {'status': 'cerrado', 'updated_at': now, 'closed_at': now},
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  Future<void> updateReportDates({
    required WeeklyReportBundle report,
    required DateTime startDate,
  }) async {
    final db = await _database.instance;
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDate = normalizedStart.add(const Duration(days: 6));
    final store = StoreType.fromCode(report.report.storeCode);
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'weekly_reports',
        {
          'title':
              '${store.label} - Reporte ${_dateLabel(normalizedStart)} - ${_dateLabel(endDate)}',
          'start_date': normalizedStart.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'status': 'borrador',
          'updated_at': now,
          'closed_at': null,
        },
        where: 'id = ?',
        whereArgs: [report.report.id],
      );

      for (var index = 0; index < report.days.length; index++) {
        await txn.update(
          'weekly_report_days',
          {
            'report_date': normalizedStart
                .add(Duration(days: index))
                .toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [report.days[index].id],
        );
      }
    });
  }

  Future<void> deleteReport(int reportId) async {
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.delete(
        'weekly_report_custom_criteria',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      await txn.delete(
        'weekly_report_days',
        where: 'report_id = ?',
        whereArgs: [reportId],
      );
      await txn.delete(
        'weekly_reports',
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });
  }

  Future<void> addCustomCriterion({
    required int reportId,
    required String name,
    required double value,
    String notes = '',
  }) async {
    final db = await _database.instance;
    await db.insert('weekly_report_custom_criteria', {
      'report_id': reportId,
      'name': name,
      'value': value,
      'notes': notes,
    });
  }

  Future<WeeklyReportBundle> _bundleFromReport(WeeklyReport report) async {
    final db = await _database.instance;
    final dayRows = await db.query(
      'weekly_report_days',
      where: 'report_id = ?',
      whereArgs: [report.id],
      orderBy: 'report_date ASC',
    );
    final criteriaRows = await db.query(
      'weekly_report_custom_criteria',
      where: 'report_id = ?',
      whereArgs: [report.id],
      orderBy: 'id ASC',
    );

    return WeeklyReportBundle(
      report: report,
      days: dayRows.map(WeeklyReportDay.fromMap).toList(),
      customCriteria: criteriaRows.map(WeeklyCustomCriterion.fromMap).toList(),
    );
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
