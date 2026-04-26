import '../domain/entities/study_goal.dart';

class PrioritizedGoal {
  final StudyGoal goal;
  final double score;

  const PrioritizedGoal({required this.goal, required this.score});
}

class PriorityCalculator {
  static const int _deadlineUrgencyDays = 7;

  /// 신규 추가된 goal (아직 한 번도 복습 안 함) 이 화면 하단으로 밀려나는
  /// 문제를 막기 위한 작은 부스트.
  /// 7일 마감 부스트(최대 7) 보다는 작게 잡아 "밀린 시험" 우선순위는 보존.
  static const double _newGoalBoost = 3.5;

  /// 그룹별 상한. 발표자료에는 4개로 적혀있지만 실 사용 시 신규 과목이 짤리는
  /// 문제가 잦아 8 (시험 4 + 학습 4) 로 늘림. 화면이 길어지면 UI 스크롤로 처리.
  static const int _maxPerGroup = 4;

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

      // 한 번도 복습 안 한 신규 goal 은 화면 상단 노출 보장
      final newBoost = goal.repetitions == 0 ? _newGoalBoost : 0.0;

      return PrioritizedGoal(
        goal: goal,
        score: overdueDays + deadlineBonus + newBoost,
      );
    }).toList();

    prioritized.sort((a, b) => b.score.compareTo(a.score));
    return prioritized;
  }

  /// 오늘의 계획: 시험 모드 [_maxPerGroup] + 학습 모드 [_maxPerGroup] 까지.
  /// 각 그룹 안에서 우선순위 높은 순으로 선택 후 합쳐서 재정렬.
  static List<PrioritizedGoal> todayPlan(List<StudyGoal> allGoals) {
    final dueGoals = allGoals.where((g) => g.isDue).toList();
    final sorted = sort(dueGoals);

    final examPicks = sorted
        .where((p) => p.goal.mode == StudyMode.exam)
        .take(_maxPerGroup);
    final studyPicks = sorted
        .where((p) => p.goal.mode == StudyMode.study)
        .take(_maxPerGroup);

    return [...examPicks, ...studyPicks]
      ..sort((a, b) => b.score.compareTo(a.score));
  }
}
