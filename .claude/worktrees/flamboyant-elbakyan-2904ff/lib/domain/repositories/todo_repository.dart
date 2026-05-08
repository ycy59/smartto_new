import '../entities/todo_item.dart';

abstract class TodoRepository {
  Future<List<TodoItem>> getByGoal(String goalId);
  Future<void> save(TodoItem item);
  Future<void> saveAll(List<TodoItem> items);
  Future<void> update(TodoItem item);
  Future<void> delete(String id);
  Future<void> deleteByGoal(String goalId);
}
