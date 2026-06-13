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
    if (items.isEmpty) return;
    await _db.insertAll('todo_items', items.map((item) => item.toMap()));
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
  Future<void> setDone(String todoId, bool isDone, {DateTime? when}) async {
    // 전체 row 를 다시 쓰지 않고 두 컬럼만 변경 — TodoItem 인스턴스 없이도
    // toggle 가능. 완료 직후 화면에서 사라진 todo 의 미완료 복귀 시 사용.
    await _db.update(
      'todo_items',
      {
        'is_done': isDone ? 1 : 0,
        'completed_at':
            isDone ? (when ?? DateTime.now()).millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [todoId],
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
