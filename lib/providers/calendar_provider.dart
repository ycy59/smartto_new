import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/study_goal.dart';
import '../domain/entities/subject.dart';
import 'database_provider.dart';

/// 캘린더 셀의 토마토 단계.
/// - high: 0.8+   (싱싱)
/// - medium: 0.6~0.8
/// - low: 0.4~0.6
/// - none: 0.0~0.4 또는 세션 없음 (시든)
enum DayFocusLevel { high, medium, low, none }

/// 그 날 복습 예정인 goal 한 건.
class CalendarReviewEntry {
  final String goalId;
  final String subjectName;
  final Color subjectColor;
  final String goalTitle;
  final UnderstandingLevel understandingLevel;
  final DateTime? lastReview;
  final DateTime nextDue;
  final int overdueDays; // 양수면 그만큼 밀린 날짜

  const CalendarReviewEntry({
    required this.goalId,
    required this.subjectName,
    required this.subjectColor,
    required this.goalTitle,
    required this.understandingLevel,
    required this.lastReview,
    required this.nextDue,
    required this.overdueDays,
  });
}

/// 한 날짜의 집중도 통계 (디테일 시트에서 사용).
class DayFocusStats {
  final double avgFocusScore; // 0.0~1.0
  final int sessionCount;
  final int totalDurationMinutes;

  const DayFocusStats({
    required this.avgFocusScore,
    required this.sessionCount,
    required this.totalDurationMinutes,
  });

  static const empty = DayFocusStats(
    avgFocusScore: 0,
    sessionCount: 0,
    totalDurationMinutes: 0,
  );

  DayFocusLevel get level {
    if (sessionCount == 0) return DayFocusLevel.none;
    if (avgFocusScore >= 0.8) return DayFocusLevel.high;
    if (avgFocusScore >= 0.6) return DayFocusLevel.medium;
    if (avgFocusScore >= 0.4) return DayFocusLevel.low;
    return DayFocusLevel.none;
  }
}

/// 한 달치 캘린더에 보여줄 데이터.
class CalendarMonthData {
  /// 'YYYY-MM-DD' 키로 그 날의 집중도 통계.
  final Map<String, DayFocusStats> focusByDay;

  /// 'YYYY-MM-DD' 키로 그 날 복습 예정인 goal 리스트.
  /// - 미래 날짜: next_due 가 그 날인 goal
  /// - 오늘: next_due <= 오늘 인 goal (밀린 것 포함)
  final Map<String, List<CalendarReviewEntry>> reviewsByDay;

  const CalendarMonthData({
    required this.focusByDay,
    required this.reviewsByDay,
  });

  static const empty = CalendarMonthData(focusByDay: {}, reviewsByDay: {});
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// 월 단위 캘린더 데이터. 인자로 해당 월의 임의 날짜 (예: 1일) 전달.
final calendarMonthDataProvider =
    FutureProvider.family<CalendarMonthData, DateTime>((ref, month) async {
  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  final sessionRepo = ref.read(studySessionRepoProvider);
  final goalRepo = ref.read(studyGoalRepoProvider);
  final subjectRepo = ref.read(subjectRepoProvider);

  // 1) 해당 월에 발생한 세션 → 일별 집중도 평균
  final sessions = await sessionRepo.getByDateRange(from, to);
  final focusByDay = <String, DayFocusStats>{};
  final byDay = <String, List<double>>{};
  final durationByDay = <String, int>{};
  for (final s in sessions) {
    final key = _dateKey(s.startedAt);
    if (s.focusScore != null) {
      (byDay[key] ??= []).add(s.focusScore!);
    }
    durationByDay[key] = (durationByDay[key] ?? 0) + (s.durationMinutes ?? 0);
  }
  for (final entry in byDay.entries) {
    final scores = entry.value;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    focusByDay[entry.key] = DayFocusStats(
      avgFocusScore: avg,
      sessionCount: scores.length,
      totalDurationMinutes: durationByDay[entry.key] ?? 0,
    );
  }
  // 세션이 있지만 focus_score 가 없는 경우도 카운트만 잡아둠 (session_count=0 으로 두면 none 처리됨)

  // 2) 모든 goal 로드 → next_due 기준으로 일별 그룹화 (해당 월에 한정)
  final allGoals = await goalRepo.getAll();
  final subjects = await subjectRepo.getAll();
  final subjectMap = <String, Subject>{for (final s in subjects) s.id: s};

  final reviewsByDay = <String, List<CalendarReviewEntry>>{};
  final today = _atMidnight(DateTime.now());

  for (final goal in allGoals) {
    final subject = subjectMap[goal.subjectId];
    if (subject == null) continue;

    final dueDay = _atMidnight(goal.nextDue);

    // 표시할 키 결정:
    // - 미래 (오늘 이후): 그 날에만 표시
    // - 오늘: 오늘에 표시 (밀린 것도 모두 흡수)
    // - 과거 (이미 지났는데 복습 안 함): 오늘 칸에 흡수 — 단, 오늘이 보고 있는 월에 있을 때만
    String displayKey;
    int overdue = 0;
    if (dueDay.isAfter(today)) {
      displayKey = _dateKey(dueDay);
    } else {
      // 오늘이거나 이미 지난 경우 → 오늘 칸으로 모음
      displayKey = _dateKey(today);
      overdue = today.difference(dueDay).inDays;
    }

    // 보고 있는 월 범위 안의 키만 채택
    final keyDate = DateTime.parse(displayKey);
    if (keyDate.isBefore(from) || keyDate.isAfter(to)) continue;

    (reviewsByDay[displayKey] ??= []).add(CalendarReviewEntry(
      goalId: goal.id,
      subjectName: subject.name,
      subjectColor: subject.color,
      goalTitle: goal.title,
      understandingLevel: goal.understandingLevel,
      lastReview: goal.lastReview,
      nextDue: goal.nextDue,
      overdueDays: overdue,
    ));
  }

  // 각 날짜별로 밀린 순 → 최신 순 정렬
  for (final list in reviewsByDay.values) {
    list.sort((a, b) {
      if (a.overdueDays != b.overdueDays) {
        return b.overdueDays.compareTo(a.overdueDays);
      }
      return a.nextDue.compareTo(b.nextDue);
    });
  }

  return CalendarMonthData(
    focusByDay: focusByDay,
    reviewsByDay: reviewsByDay,
  );
});
