import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/debt.dart';

class DebtRepository {
  DebtRepository(this._database);

  final AppDatabase _database;

  Future<List<Debt>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query('debts', orderBy: 'due_date ASC, id DESC');
    return rows.map(Debt.fromMap).toList();
  }

  Future<int> insert(Debt debt) async {
    final db = await _database.instance;
    return db.insert('debts', debt.toMap()..remove('id'));
  }
}
