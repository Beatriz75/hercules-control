import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/line_assignment.dart';
import 'package:hercules_control/domain/entities/phone_line.dart';

class LineRepository {
  LineRepository(this._database);

  final AppDatabase _database;

  Future<List<PhoneLine>> fetchLines() async {
    final db = await _database.instance;
    final rows = await db.query(
      'phone_lines',
      orderBy: 'status ASC, alias ASC',
    );
    return rows.map(PhoneLine.fromMap).toList();
  }

  Future<List<LineAssignment>> fetchAssignments() async {
    final db = await _database.instance;
    final rows = await db.query(
      'line_assignments',
      orderBy: 'assigned_at DESC, id DESC',
    );
    return rows.map(LineAssignment.fromMap).toList();
  }

  Future<Map<int, int>> fetchCurrentLineByEmployee() async {
    final db = await _database.instance;
    final rows = await db.query(
      'line_assignments',
      where: 'status = ?',
      whereArgs: ['activa'],
    );

    return {
      for (final row in rows) row['employee_id'] as int: row['line_id'] as int,
    };
  }

  Future<int> insertLine(PhoneLine line) async {
    final db = await _database.instance;
    return db.insert('phone_lines', line.toMap()..remove('id'));
  }

  Future<int> assignLine(LineAssignment assignment) async {
    final db = await _database.instance;
    return db.transaction((txn) async {
      final removedAt = assignment.assignedAt.toIso8601String();
      await txn.update(
        'line_assignments',
        {'removed_at': removedAt, 'status': 'retirada'},
        where: 'line_id = ? AND status = ?',
        whereArgs: [assignment.lineId, 'activa'],
      );
      await txn.update(
        'line_assignments',
        {'removed_at': removedAt, 'status': 'retirada'},
        where: 'employee_id = ? AND status = ?',
        whereArgs: [assignment.employeeId, 'activa'],
      );
      return txn.insert('line_assignments', assignment.toMap()..remove('id'));
    });
  }

  Future<void> retireAssignment(int assignmentId) async {
    final db = await _database.instance;
    await db.update(
      'line_assignments',
      {'removed_at': DateTime.now().toIso8601String(), 'status': 'retirada'},
      where: 'id = ? AND status = ?',
      whereArgs: [assignmentId, 'activa'],
    );
  }
}
