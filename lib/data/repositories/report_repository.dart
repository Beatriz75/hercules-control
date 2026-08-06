import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/report_case.dart';

class ReportRepository {
  ReportRepository(this._database);

  final AppDatabase _database;

  Future<List<ReportCase>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query('reports', orderBy: 'report_date DESC, id DESC');
    return rows.map(ReportCase.fromMap).toList();
  }

  Future<int> insert(ReportCase report) async {
    final db = await _database.instance;
    return db.insert('reports', report.toMap()..remove('id'));
  }
}
