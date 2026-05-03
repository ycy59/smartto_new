import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../algorithms/priority_calculator.dart';
import '../domain/entities/study_goal.dart';
import '../domain/entities/subject.dart';
import 'calendar_provider.dart';
import 'database_provider.dart';

class TodayPlanEntry {
  final Subject subject;
  final StudyGoal goal;
  final double priorityScore;

  const TodayPlanEntry({
    required this.subject,
    required this.goal,
    required this.priorityScore,
  });
}

final todayPlanProvider =
    AsyncNotifierProvider<TodayPlanNotifier, List<TodayPlanEntry>>(
  TodayPlanNotifier.new,
);

class TodayPlanNotifier extends AsyncNotifier<List<TodayPlanEntry>> {
  @override
  Future<List<TodayPlanEntry>> build() async {
    final goals = await ref.read(studyGoalRepoProvider).getDueToday();
    final subjects = await ref.read(subjectRepoProvider).getAll();
    final subjectMap = {for (final s in subjects) s.id: s};

    return PriorityCalculator.todayPlan(goals)
        .where((p) => subjectMap.containsKey(p.goal.subjectId))
        .map((p) {
          // 완료(isDone) todo는 화면에서 즉시 사라지도록 제거
          // priority 높은 순으로 정렬
          final sortedTodos = p.goal.todos
              .where((t) => !t.isDone)
              .toList()
            ..sort((a, b) => b.priority.compareTo(a.priority));
          return TodayPlanEntry(
            subject: subjectMap[p.goal.subjectId]!,
            goal: p.goal.copyWith(todos: sortedTodos),
            priorityScore: p.score,
          );
        })
        .toList();
  }

  void refresh() => ref.invalidateSelf();

  /// 할 일 토글:
  /// 1) **즉시** 로컬 state 업데이트 (done이면 리스트에서 제거) → 사용자 피드백 instant
  /// 2) DB 영속화는 백그라운드에서
  /// 3) 캘린더 점도 같이 갱신해야 하니 calendar provider invalidate
  Future<void> toggleTodoDone(String todoId, bool isDone) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 원본 todo 추출 (DB 업데이트용)
    final original = current
        .expand((e) => e.goal.todos)
        .where((t) => t.id == todoId)
        .toList();
    if (original.isEmpty) return;
    final targetTodo = original.first;

    // 1) 옵티미스틱 업데이트 — done이면 리스트에서 제거, 아니면 토글
    final updated = current.map((entry) {
      final newTodos = entry.goal.todos
          .map((t) => t.id == todoId ? t.toggleDone(isDone) : t)
          .where((t) => !t.isDone)
          .toList();
      return TodayPlanEntry(
        subject: entry.subject,
        goal: entry.goal.copyWith(todos: newTodos),
        priorityScore: entry.priorityScore,
      );
    }).toList();
    state = AsyncData(updated);

    // 2) DB 쓰기 (await — 실패 시 재시도/롤백 로직은 여기 추가 가능)
    await ref
        .read(todoRepoProvider)
        .update(targetTodo.toggleDone(isDone));

    // 3) 캘린더 다음 빌드 때 새 데이터 반영
    ref.invalidate(calendarMonthDataProvider);
  }
}
