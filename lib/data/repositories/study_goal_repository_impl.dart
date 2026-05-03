import '../../algorithms/fsrs/fsrs_state.dart';
import '../../domain/entities/study_goal.dart';
import '../../domain/entities/todo_item.dart';
import '../../domain/repositories/study_goal_repository.dart';
import '../db/database_helper.dart';

class StudyGoalRepositoryImpl implements StudyGoalRepository {
  final DatabaseHelper _db;
  StudyGoalRepositoryImpl(this._db);

  Future<List<TodoItem>> _todosFor(String goalId) async {
    final rows = await _db.query(
      'todo_items',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'position ASC',
    );
    return rows.map(TodoItem.fromMap).toList();
  }

  Future<StudyGoal> _withTodos(Map<String, dynamic> row) async {
    final todos = await _todosFor(row['id'] as String);
    return StudyGoal.fromMap(row, todos: todos);
  }

  @override
  Future<List<StudyGoal>> getAll() async {
    final rows = await _db.query(
      'study_goals',
      orderBy: 'next_due ASC',
    );
    return Future.wait(rows.map(_withTodos));
  }

  @override
  Future<List<StudyGoal>> getBySubject(String subjectId) async {
    final rows = await _db.query(
      'study_goals',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'next_due ASC',
    );
    return Future.wait(rows.map(_withTodos));
  }

  @override
  Future<List<StudyGoal>> getDueToday() async {
    final todayEnd = DateTime.now();
    final endOfDay = DateTime(todayEnd.year, todayEnd.month, todayEnd.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final rows = await _db.query(
      'study_goals',
      where: 'next_due <= ?',
      whereArgs: [endOfDay],
      orderBy: 'next_due ASC',
    );
    return Future.wait(rows.map(_withTodos));
  }

  @override
  Future<StudyGoal?> getById(String id) async {
    final rows =
        await _db.query('study_goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _withTodos(rows.first);
  }

  @override
  Future<void> save(StudyGoal goal) async {
    final existing = await getById(goal.id);
    if (existing != null) {
      await _db.update(
        'study_goals',
        goal.toMap(),
        where: 'id = ?',
        whereArgs: [goal.id],
      );
    } else {
      await _db.insert('study_goals', goal.toMap());
    }
  }

  @override
  Future<void> updateFsrs(StudyGoal goal) async {
    await _db.update(
      'study_goals',
      {
        'stability': goal.stability,
        'difficulty': goal.difficulty,
        'retrievability': goal.retrievability,
        'repetitions': goal.repetitions,
        'state': goal.state.toDbString(),
        'last_review': goal.lastReview?.millisecondsSinceEpoch,
        'next_due': goal.nextDue.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('study_goals', where: 'id = ?', whereArgs: [id]);
  }
}
