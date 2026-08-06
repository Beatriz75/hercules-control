import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/employee_payment.dart';

class EmployeePaymentRepository {
  EmployeePaymentRepository(this._database);

  final AppDatabase _database;

  Future<List<EmployeePayment>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query(
      'employee_payments',
      orderBy: 'payment_date DESC, id DESC',
    );
    return rows.map(EmployeePayment.fromMap).toList();
  }

  Future<int> insert(EmployeePayment payment) async {
    final db = await _database.instance;
    return db.insert('employee_payments', payment.toMap()..remove('id'));
  }
}
