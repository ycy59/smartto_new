import '../../domain/entities/todo_item.dart';
import '../../domain/repositories/todo_repository.dart';
import '../db/database_helper.dart';

class TodoRepositoryImpl implements TodoRepository {
  final DatabaseHelper _db;
  TodoRepositoryImpl(this._db);

  @override
  Future<List<TodoItem>> getByGoal(String goalId) async {
    final rows = await _db.query(
      'todo_items',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'position ASC',
    );
    return rows.map(TodoItem.fromMap).toList();
  }

  @override
  Future<void> save(TodoItem item) async {
    await _db.insert('todo_items', item.toMap());
  }

  @override
  Future<void> saveAll(List<TodoItem> items) async {
    for (final item in items) {
      await _db.insert('todo_items', item.toMap());
    }
  }

  @override
  Future<void> update(TodoItem item) async {
    await _db.update(
      'todo_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('todo_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteByGoal(String goalId) async {
    await _db.delete('todo_items', where: 'goal_id = ?', whereArgs: [goalId]);
  }
}
