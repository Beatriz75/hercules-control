import 'package:hercules_control/data/local/app_database.dart';
import 'package:hercules_control/domain/entities/daily_review.dart';

class DailyReviewRepository {
  DailyReviewRepository(this._database);

  final AppDatabase _database;

  Future<List<DailyReview>> fetchAll() async {
    final db = await _database.instance;
    final rows = await db.query('daily_reviews', orderBy: 'review_date DESC');
    return rows.map(DailyReview.fromMap).toList();
  }

  Future<int> insert(DailyReview review) async {
    final db = await _database.instance;
    return db.insert('daily_reviews', review.toMap()..remove('id'));
  }
}
