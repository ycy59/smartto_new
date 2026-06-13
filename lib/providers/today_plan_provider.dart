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
    // 오늘의 계획 = "미완료 todo 가 1개 이상인 goal"
    // FSRS next_due 는 정렬 우선순위에만 사용하고 가시성 필터로는 쓰지 않음.
    // (이전엔 next_due <= today 로 필터링 → FSRS Again 시 next_due 가 미래로
    //  점프하면서 사용자가 ▶ 누르고 backout 만 해도 과목이 사라지는 문제 발생)
    final goalsFuture = ref.read(studyGoalRepoProvider).getAll();
    final subjectsFuture = ref.read(subjectRepoProvider).getAll();
    final goals = await goalsFuture;
    final subjects = await subjectsFuture;
    final subjectMap = {for (final s in subjects) s.id: s};

    return PriorityCalculator.todayPlan(goals)
        .where((p) =>
            subjectMap.containsKey(p.goal.subjectId) &&
            p.goal.todos.any((t) => !t.isDone))
        .map((p) {
      // 완료(isDone) todo는 화면에서 즉시 사라지도록 제거
      // priority 높은 순으로 정렬
      final sortedTodos = p.goal.todos.where((t) => !t.isDone).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
      return TodayPlanEntry(
        subject: subjectMap[p.goal.subjectId]!,
        goal: p.goal.copyWith(todos: sortedTodos),
        priorityScore: p.score,
      );
    }).toList();
  }

  void refresh() => ref.invalidateSelf();

  /// 할 일 토글:
  /// 1) state 에 해당 todo 가 있으면 옵티미스틱 업데이트 (완료면 리스트에서 제거)
  ///    → 홈 화면 즉시 반영
  /// 2) DB 는 [TodoRepository.setDone] 으로 항상 갱신 (state 에 없어도 OK)
  /// 3) 미완료 토글(isDone=false) 이면 self invalidate → 다음 빌드에서
  ///    오늘의 계획에 다시 노출
  /// 4) 캘린더도 갱신 (완료 todo 카운트 반영)
  ///
  /// 카메라 페이지에서 완료 후 다시 미완료로 되돌리는 경우, state 의 build()
  /// 가 이미 done 을 필터링해 todo 가 빠져 있을 수 있음 → 그럴 땐 옵티미스틱
  /// 업데이트는 스킵하고 DB + invalidate 만 수행.
  Future<void> toggleTodoDone(String todoId, bool isDone) async {
    final current = state.valueOrNull;

    // 1) state 에 있으면 옵티미스틱 업데이트 (완료된 항목은 화면에서 제거)
    if (current != null) {
      final hasInState =
          current.expand((e) => e.goal.todos).any((t) => t.id == todoId);
      if (hasInState) {
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
      }
    }

    // 2) DB 영속화 — todoId 만으로 부분 업데이트. state 에 없어도 항상 동작.
    await ref.read(todoRepoProvider).setDone(todoId, isDone);

    // 3) 미완료 복귀라면 다음 빌드에서 다시 노출되도록 self invalidate.
    //    (옵티미스틱 업데이트만으로는 빠진 todo 를 되살릴 수 없음)
    if (!isDone) {
      ref.invalidateSelf();
    }

    // 4) 캘린더의 완료 todo 카운트도 갱신
    ref.invalidate(calendarMonthDataProvider);
  }
}
