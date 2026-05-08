import '../entities/todo_item.dart';

abstract class TodoRepository {
  Future<List<TodoItem>> getByGoal(String goalId);
  Future<void> save(TodoItem item);
  Future<void> saveAll(List<TodoItem> items);
  Future<void> update(TodoItem item);

  /// is_done + completed_at 두 컬럼만 부분 업데이트.
  /// 호출자가 [TodoItem] 전체를 손에 들고 있지 않아도 토글 가능 — 특히
  /// 완료 후 화면 state 에서 빠진 todo 를 다시 미완료로 되돌릴 때 사용.
  /// - isDone=true  : completed_at = [when] (없으면 DateTime.now())
  /// - isDone=false : completed_at = null
  Future<void> setDone(String todoId, bool isDone, {DateTime? when});

  Future<void> delete(String id);
  Future<void> deleteByGoal(String goalId);
}
