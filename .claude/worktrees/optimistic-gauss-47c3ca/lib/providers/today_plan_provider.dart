import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../algorithms/priority_calculator.dart';
import '../domain/entities/study_goal.dart';
import '../domain/entities/subject.dart';
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
          // 할 일을 priority 높은 순으로 정렬
          final sortedTodos = List.of(p.goal.todos)
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

  Future<void> toggleTodoDone(String todoId, bool isDone) async {
    final todos = state.valueOrNull
        ?.expand((e) => e.goal.todos)
        .where((t) => t.id == todoId)
        .toList();
    if (todos == null || todos.isEmpty) return;

    final todo = todos.first;
    // toggleDone(): is_done 변경에 맞춰 completed_at 자동 갱신
    await ref.read(todoRepoProvider).update(todo.toggleDone(isDone));
    ref.invalidateSelf();
  }
}
