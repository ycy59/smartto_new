import '../domain/entities/study_goal.dart';

class PrioritizedGoal {
  final StudyGoal goal;
  final double score;

  const PrioritizedGoal({required this.goal, required this.score});
}

class PriorityCalculator {
  static const int _deadlineUrgencyDays = 7;

  /// 전체 목표 우선순위 점수 계산 후 정렬
  static List<PrioritizedGoal> sort(List<StudyGoal> goals) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final prioritized = goals.map((goal) {
      final nextDueDay = DateTime(
        goal.nextDue.year,
        goal.nextDue.month,
        goal.nextDue.day,
      );
      final overdueDays = today.difference(nextDueDay).inDays.toDouble();

      double deadlineBonus = 0;
      if (goal.mode == StudyMode.exam && goal.dueDate != null) {
        final daysLeft = goal.daysUntilDeadline ?? 999;
        if (daysLeft >= 0 && daysLeft <= _deadlineUrgencyDays) {
          deadlineBonus = (_deadlineUrgencyDays - daysLeft).toDouble();
        }
      }

      return PrioritizedGoal(
        goal: goal,
        score: overdueDays + deadlineBonus,
      );
    }).toList();

    prioritized.sort((a, b) => b.score.compareTo(a.score));
    return prioritized;
  }

  /// 오늘의 계획: 시험 모드 최대 2개 + 학습 모드 최대 2개 = 최대 4개
  /// 각 그룹 안에서 우선순위 높은 순으로 선택 후 합쳐서 재정렬
  static List<PrioritizedGoal> todayPlan(List<StudyGoal> allGoals) {
    final dueGoals = allGoals.where((g) => g.isDue).toList();
    final sorted = sort(dueGoals);

    final examPicks =
        sorted.where((p) => p.goal.mode == StudyMode.exam).take(2);
    final studyPicks =
        sorted.where((p) => p.goal.mode == StudyMode.study).take(2);

    return [...examPicks, ...studyPicks]
      ..sort((a, b) => b.score.compareTo(a.score));
  }
}
