import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/employee.dart';

class EmployeeRepository {
  EmployeeRepository(this._database);

  final AppDatabase _database;

  Future<List<Employee>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query('employees', orderBy: 'status ASC, name ASC');
    return rows.map(Employee.fromMap).toList();
  }

  Future<int> insert(Employee employee) async {
    final db = await _database.instance;
    return db.insert('employees', employee.toMap()..remove('id'));
  }
}
