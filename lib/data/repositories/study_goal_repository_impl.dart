import '../../algorithms/fsrs/fsrs_state.dart';
import '../../domain/entities/study_goal.dart';
import '../../domain/entities/todo_item.dart';
import '../../domain/repositories/study_goal_repository.dart';
import '../db/database_helper.dart';

class StudyGoalRepositoryImpl implements StudyGoalRepository {
  final DatabaseHelper _db;
  StudyGoalRepositoryImpl(this._db);

  Future<List<StudyGoal>> _withTodosForRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];

    final goalIds = rows.map((row) => row['id'] as String).toList();
    final placeholders = List.filled(goalIds.length, '?').join(',');
    final todoRows = await _db.query(
      'todo_items',
      where: 'goal_id IN ($placeholders)',
      whereArgs: goalIds,
      orderBy: 'goal_id ASC, position ASC',
    );

    final todosByGoal = <String, List<TodoItem>>{};
    for (final todoRow in todoRows) {
      final todo = TodoItem.fromMap(todoRow);
      (todosByGoal[todo.goalId] ??= []).add(todo);
    }

    return rows
        .map(
          (row) => StudyGoal.fromMap(
            row,
            todos: todosByGoal[row['id'] as String] ?? const <TodoItem>[],
          ),
        )
        .toList();
  }

  @override
  Future<List<StudyGoal>> getAll() async {
    final rows = await _db.query(
      'study_goals',
      orderBy: 'next_due ASC',
    );
    return _withTodosForRows(rows);
  }

  @override
  Future<List<StudyGoal>> getAllWithoutTodos() async {
    final rows = await _db.query(
      'study_goals',
      orderBy: 'next_due ASC',
    );
    return rows.map(StudyGoal.fromMap).toList();
  }

  @override
  Future<List<StudyGoal>> getBySubject(String subjectId) async {
    final rows = await _db.query(
      'study_goals',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'next_due ASC',
    );
    return _withTodosForRows(rows);
  }

  @override
  Future<List<StudyGoal>> getDueToday() async {
    final todayEnd = DateTime.now();
    final endOfDay =
        DateTime(todayEnd.year, todayEnd.month, todayEnd.day, 23, 59, 59)
            .millisecondsSinceEpoch;
    final rows = await _db.query(
      'study_goals',
      where: 'next_due <= ?',
      whereArgs: [endOfDay],
      orderBy: 'next_due ASC',
    );
    return _withTodosForRows(rows);
  }

  @override
  Future<StudyGoal?> getById(String id) async {
    final rows =
        await _db.query('study_goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return (await _withTodosForRows(rows)).first;
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
