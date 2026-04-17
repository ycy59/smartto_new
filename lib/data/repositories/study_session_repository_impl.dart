import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_session_repository.dart';
import '../db/database_helper.dart';

class StudySessionRepositoryImpl implements StudySessionRepository {
  final DatabaseHelper _db;
  StudySessionRepositoryImpl(this._db);

  @override
  Future<List<StudySession>> getByGoal(String goalId) async {
    final rows = await _db.query(
      'study_sessions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'started_at DESC',
    );
    return rows.map(StudySession.fromMap).toList();
  }

  @override
  Future<List<StudySession>> getByDateRange(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'study_sessions',
      where: 'started_at >= ? AND started_at <= ?',
      whereArgs: [
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
      orderBy: 'started_at DESC',
    );
    return rows.map(StudySession.fromMap).toList();
  }

  @override
  Future<void> save(StudySession session) async {
    await _db.insert('study_sessions', session.toMap());
  }

  @override
  Future<void> update(StudySession session) async {
    await _db.update(
      'study_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }
}
