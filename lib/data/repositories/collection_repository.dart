import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/collection_record.dart';

class CollectionRepository {
  CollectionRepository(this._database);

  final AppDatabase _database;

  Future<List<CollectionRecord>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query('collections', orderBy: 'payment_date DESC');
    return rows.map(CollectionRecord.fromMap).toList();
  }

  Future<int> insert(CollectionRecord collection) async {
    final db = await _database.instance;
    return db.insert('collections', collection.toMap()..remove('id'));
  }
}
