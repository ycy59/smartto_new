import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  기존 statsProvider — 메인 화면 GreetingCard / WeeklyStatsCard 가 의존.
// ═══════════════════════════════════════════════════════════════════════════

class StudyStats {
  final int todayMinutes;       // 오늘 실제 학습 시간 (분)
  final int goalMinutes;        // 온보딩에서 설정한 목표 시간 (분)
  final int weeklyMinutes;      // 이번주 총 집중 (분)
  final int weeklySessionCount; // 이번주 완료 세션 수
  final double? weeklyAvgFocus; // 이번주 평균 집중도 (0~100)

  const StudyStats({
    required this.todayMinutes,
    required this.goalMinutes,
    required this.weeklyMinutes,
    required this.weeklySessionCount,
    this.weeklyAvgFocus,
  });

  static const empty = StudyStats(
    todayMinutes: 0,
    goalMinutes: 120,
    weeklyMinutes: 0,
    weeklySessionCount: 0,
  );
}

final statsProvider =
    AsyncNotifierProvider<StatsNotifier, StudyStats>(StatsNotifier.new);

class StatsNotifier extends AsyncNotifier<StudyStats> {
  @override
  Future<StudyStats> build() async {
    final db = ref.read(databaseHelperProvider);
    final prefs = await SharedPreferences.getInstance();

    final goalStr = prefs.getString('study_time_goal') ?? '2시간';
    final goalMinutes = _parseGoalMinutes(goalStr);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    // 이번주 월요일 자정
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .millisecondsSinceEpoch;

    // 오늘 학습 시간
    final todayRows = await db.rawQuery('''
      SELECT COALESCE(SUM(duration_minutes), 0) AS total
      FROM study_sessions
      WHERE started_at >= ? AND ended_at IS NOT NULL
    ''', [todayStart]);
    final todayMinutes =
        (todayRows.first['total'] as num? ?? 0).toInt();

    // 이번주 통계
    final weekRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(duration_minutes), 0)  AS total_min,
        COUNT(*)                             AS session_cnt,
        AVG(focus_score)                     AS avg_focus
      FROM study_sessions
      WHERE started_at >= ? AND ended_at IS NOT NULL
    ''', [weekStart]);

    final row = weekRows.first;
    final weeklyMinutes = (row['total_min'] as num? ?? 0).toInt();
    final weeklySessionCount = (row['session_cnt'] as num? ?? 0).toInt();
    final rawFocus = row['avg_focus'];
    final weeklyAvgFocus = rawFocus != null
        ? ((rawFocus as num).toDouble() * 100).roundToDouble()
        : null;

    return StudyStats(
      todayMinutes: todayMinutes,
      goalMinutes: goalMinutes,
      weeklyMinutes: weeklyMinutes,
      weeklySessionCount: weeklySessionCount,
      weeklyAvgFocus: weeklyAvgFocus,
    );
  }

  void refresh() => ref.invalidateSelf();

  static int _parseGoalMinutes(String s) => switch (s) {
        '1시간' => 60,
        '2시간' => 120,
        '4시간' => 240,
        '5시간+' => 300,
        _ => 120,
      };
}

/// 분 → 'XH YM' 형식 (예: 85분 → '1H 25M')
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0M';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}M';
  if (m == 0) return '${h}H';
  return '${h}H ${m.toString().padLeft(2, '0')}M';
}

// ═══════════════════════════════════════════════════════════════════════════
//  리포트 페이지용 5종 집계 — ReportQueries (정적) + FutureProvider.family
//
//  [중요] 시간 처리 원칙:
//  · DB의 started_at / completed_at 은 millisecondsSinceEpoch (UTC 타임스탬프).
//  · 일자/시간대 버킷은 모두 device-local 기준 — DateTime(year, month, day)
//    로 자정을 만들고 .millisecondsSinceEpoch 으로 UTC 변환해 SQL 비교.
//  · 시간(hour) 추출은 DateTime.fromMillisecondsSinceEpoch(...).hour 가
//    local hour 를 반환하므로 Dart 측에서 처리 (SQL strftime 사용 안 함).
// ═══════════════════════════════════════════════════════════════════════════

/// 일간 시간대별 버킷 — _HourlyBarChart 의 단위.
class HourlyBucket {
  final int hour;            // 0~23 (local)
  final String subjectId;
  final String subjectName;
  final int subjectColor;    // ARGB int
  final int minutes;
  final double? avgFocus;    // 0~100, null 이면 해당 버킷에 focus_score 가 하나도 없음

  const HourlyBucket({
    required this.hour,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
    required this.minutes,
    required this.avgFocus,
  });
}

/// 일간 통계 카드 3종 (총 집중 시간 / 완료 todo 수 / 평균 집중도).
class DailyReport {
  final int totalMinutes;
  final int completedTodos;  // 그 날 completed_at 이 찍힌 todo 수
  final double? avgFocus;    // 0~100

  const DailyReport({
    required this.totalMinutes,
    required this.completedTodos,
    required this.avgFocus,
  });

  static const empty = DailyReport(
    totalMinutes: 0,
    completedTodos: 0,
    avgFocus: null,
  );
}

/// 일간 도넛 — 시험 모드 vs 학습 모드 비율.
class ModeRatio {
  final int examMinutes;
  final int studyMinutes;

  const ModeRatio({required this.examMinutes, required this.studyMinutes});

  int get totalMinutes => examMinutes + studyMinutes;

  /// 0.0~1.0 — total 이 0 이면 0 반환.
  double get examRatio =>
      totalMinutes == 0 ? 0.0 : examMinutes / totalMinutes;
  double get studyRatio =>
      totalMinutes == 0 ? 0.0 : studyMinutes / totalMinutes;

  static const empty = ModeRatio(examMinutes: 0, studyMinutes: 0);
}

/// Activity 타임라인 한 줄 — goal 단위.
class ActivityEntry {
  final String sessionId;
  final DateTime startedAt;
  final int? durationMinutes;
  final double? focusScore;       // 0.0~1.0 (raw)
  final String goalTitle;
  final String subjectName;
  final int subjectColor;

  const ActivityEntry({
    required this.sessionId,
    required this.startedAt,
    required this.durationMinutes,
    required this.focusScore,
    required this.goalTitle,
    required this.subjectName,
    required this.subjectColor,
  });
}

/// 주간 일별/과목별 매트릭스 한 셀.
class DaySubjectBucket {
  final DateTime day;        // local midnight
  final String subjectId;
  final String subjectName;
  final int subjectColor;
  final int minutes;

  const DaySubjectBucket({
    required this.day,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
    required this.minutes,
  });
}

/// 주간 리포트 종합.
class WeeklyReport {
  final List<DaySubjectBucket> buckets;
  final int totalMinutes;
  final int completedTodos;
  final DateTime? maxFocusDay;
  final double? maxFocusValue;   // 0~100

  const WeeklyReport({
    required this.buckets,
    required this.totalMinutes,
    required this.completedTodos,
    required this.maxFocusDay,
    required this.maxFocusValue,
  });

  static const empty = WeeklyReport(
    buckets: [],
    totalMinutes: 0,
    completedTodos: 0,
    maxFocusDay: null,
    maxFocusValue: null,
  );
}

// ───────────────────────────────────────────────────────────────────────────
//  쿼리 구현부 — sqflite [Database] 직접 사용 (테스트에서 in-memory DB 주입).
// ───────────────────────────────────────────────────────────────────────────

class ReportQueries {
  ReportQueries._();

  /// ① 일간 시간대 × 과목 매트릭스 — _HourlyBarChart.
  static Future<List<HourlyBucket>> getDailyHourlyBuckets(
    Database db,
    DateTime date,
  ) async {
    final bounds = _DateBounds.day(date);
    final rows = await db.rawQuery('''
      SELECT
        ss.started_at      AS started_at,
        ss.duration_minutes AS minutes,
        ss.focus_score      AS focus,
        s.id                AS subject_id,
        s.name              AS subject_name,
        s.color             AS subject_color
      FROM study_sessions ss
      JOIN study_goals    sg ON ss.goal_id    = sg.id
      JOIN subjects       s  ON sg.subject_id = s.id
      WHERE ss.started_at >= ?
        AND ss.started_at <  ?
        AND ss.ended_at IS NOT NULL
      ORDER BY ss.started_at ASC
    ''', [bounds.startMs, bounds.endMs]);

    // (hour, subjectId) → 누적 minutes / 가중 focus 합
    final agg = <String, _BucketAgg>{};
    for (final row in rows) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
          (row['started_at'] as num).toInt());
      final hour = startedAt.hour;
      final subjectId = row['subject_id'] as String;
      final key = '$hour|$subjectId';

      final minutes = (row['minutes'] as num?)?.toInt() ?? 0;
      final focus = (row['focus'] as num?)?.toDouble();

      final cur = agg.putIfAbsent(
        key,
        () => _BucketAgg(
          hour: hour,
          subjectId: subjectId,
          subjectName: row['subject_name'] as String,
          subjectColor: (row['subject_color'] as num).toInt(),
        ),
      );
      cur.minutes += minutes;
      if (focus != null && minutes > 0) {
        cur.focusWeightedSum += focus * minutes;
        cur.focusWeightMinutes += minutes;
      }
    }

    final buckets = agg.values
        .map((a) => HourlyBucket(
              hour: a.hour!,
              subjectId: a.subjectId!,
              subjectName: a.subjectName!,
              subjectColor: a.subjectColor!,
              minutes: a.minutes,
              avgFocus: a.focusWeightMinutes > 0
                  ? double.parse(
                      ((a.focusWeightedSum / a.focusWeightMinutes) * 100)
                          .toStringAsFixed(1))
                  : null,
            ))
        .toList()
      ..sort((x, y) {
        final hCmp = x.hour.compareTo(y.hour);
        if (hCmp != 0) return hCmp;
        return x.subjectId.compareTo(y.subjectId);
      });
    return buckets;
  }

  /// ② 일간 통계 카드 (총 집중 / 완료 todo / 평균 집중도).
  static Future<DailyReport> getDailyReport(
    Database db,
    DateTime date,
  ) async {
    final bounds = _DateBounds.day(date);

    final sessRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(duration_minutes), 0) AS total_min,
        AVG(focus_score)                   AS avg_focus
      FROM study_sessions
      WHERE started_at >= ?
        AND started_at <  ?
        AND ended_at IS NOT NULL
    ''', [bounds.startMs, bounds.endMs]);

    final todoRows = await db.rawQuery('''
      SELECT COUNT(*) AS done_count
      FROM todo_items
      WHERE completed_at IS NOT NULL
        AND completed_at >= ?
        AND completed_at <  ?
    ''', [bounds.startMs, bounds.endMs]);

    final totalMin = (sessRows.first['total_min'] as num? ?? 0).toInt();
    final rawFocus = sessRows.first['avg_focus'];
    final avgFocus = rawFocus != null
        ? double.parse(((rawFocus as num).toDouble() * 100).toStringAsFixed(1))
        : null;
    final doneCnt =
        (todoRows.first['done_count'] as num? ?? 0).toInt();

    return DailyReport(
      totalMinutes: totalMin,
      completedTodos: doneCnt,
      avgFocus: avgFocus,
    );
  }

  /// ③ 일간 도넛 — exam vs study 모드 시간 비율.
  static Future<ModeRatio> getDailyModeRatio(
    Database db,
    DateTime date,
  ) async {
    final bounds = _DateBounds.day(date);

    final rows = await db.rawQuery('''
      SELECT
        sg.mode                            AS mode,
        COALESCE(SUM(ss.duration_minutes), 0) AS minutes
      FROM study_sessions ss
      JOIN study_goals    sg ON ss.goal_id = sg.id
      WHERE ss.started_at >= ?
        AND ss.started_at <  ?
        AND ss.ended_at IS NOT NULL
      GROUP BY sg.mode
    ''', [bounds.startMs, bounds.endMs]);

    int exam = 0, study = 0;
    for (final r in rows) {
      final minutes = (r['minutes'] as num? ?? 0).toInt();
      if ((r['mode'] as String?) == 'exam') {
        exam += minutes;
      } else {
        study += minutes;
      }
    }
    return ModeRatio(examMinutes: exam, studyMinutes: study);
  }

  /// ④ 일간 Activity 타임라인 — goal 단위, 시작시각 오름차순.
  static Future<List<ActivityEntry>> getDailyActivities(
    Database db,
    DateTime date,
  ) async {
    final bounds = _DateBounds.day(date);

    final rows = await db.rawQuery('''
      SELECT
        ss.id               AS id,
        ss.started_at       AS started_at,
        ss.duration_minutes AS minutes,
        ss.focus_score      AS focus,
        sg.title            AS goal_title,
        s.name              AS subject_name,
        s.color             AS subject_color
      FROM study_sessions ss
      JOIN study_goals    sg ON ss.goal_id    = sg.id
      JOIN subjects       s  ON sg.subject_id = s.id
      WHERE ss.started_at >= ?
        AND ss.started_at <  ?
        AND ss.ended_at IS NOT NULL
      ORDER BY ss.started_at ASC
    ''', [bounds.startMs, bounds.endMs]);

    return rows
        .map((r) => ActivityEntry(
              sessionId: r['id'] as String,
              startedAt: DateTime.fromMillisecondsSinceEpoch(
                  (r['started_at'] as num).toInt()),
              durationMinutes: (r['minutes'] as num?)?.toInt(),
              focusScore: (r['focus'] as num?)?.toDouble(),
              goalTitle: r['goal_title'] as String,
              subjectName: r['subject_name'] as String,
              subjectColor: (r['subject_color'] as num).toInt(),
            ))
        .toList();
  }

  /// ⑤ 주간 리포트 — 7일 매트릭스 + 최고 집중일 + 누적 totals.
  /// [weekStart] 는 보통 월요일 00:00 local.
  static Future<WeeklyReport> getWeeklyReport(
    Database db,
    DateTime weekStart,
  ) async {
    final bounds = _DateBounds.week(weekStart);

    final sessRows = await db.rawQuery('''
      SELECT
        ss.started_at       AS started_at,
        ss.duration_minutes AS minutes,
        ss.focus_score      AS focus,
        s.id                AS subject_id,
        s.name              AS subject_name,
        s.color             AS subject_color
      FROM study_sessions ss
      JOIN study_goals    sg ON ss.goal_id    = sg.id
      JOIN subjects       s  ON sg.subject_id = s.id
      WHERE ss.started_at >= ?
        AND ss.started_at <  ?
        AND ss.ended_at IS NOT NULL
      ORDER BY ss.started_at ASC
    ''', [bounds.startMs, bounds.endMs]);

    final todoRows = await db.rawQuery('''
      SELECT COUNT(*) AS done_count
      FROM todo_items
      WHERE completed_at IS NOT NULL
        AND completed_at >= ?
        AND completed_at <  ?
    ''', [bounds.startMs, bounds.endMs]);

    // (day, subjectId) → minutes
    final cells = <String, _BucketAgg>{};
    // day → focus weighted (for maxFocusDay)
    final dayFocus = <DateTime, _BucketAgg>{};
    int totalMinutes = 0;

    for (final row in sessRows) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
          (row['started_at'] as num).toInt());
      final day =
          DateTime(startedAt.year, startedAt.month, startedAt.day);

      final subjectId = row['subject_id'] as String;
      final cellKey = '${day.millisecondsSinceEpoch}|$subjectId';

      final minutes = (row['minutes'] as num?)?.toInt() ?? 0;
      final focus = (row['focus'] as num?)?.toDouble();

      final cell = cells.putIfAbsent(
        cellKey,
        () => _BucketAgg(
          subjectId: subjectId,
          subjectName: row['subject_name'] as String,
          subjectColor: (row['subject_color'] as num).toInt(),
          day: day,
        ),
      );
      cell.minutes += minutes;
      totalMinutes += minutes;

      final dayAgg = dayFocus.putIfAbsent(
        day,
        () => _BucketAgg(day: day),
      );
      dayAgg.minutes += minutes;
      if (focus != null && minutes > 0) {
        dayAgg.focusWeightedSum += focus * minutes;
        dayAgg.focusWeightMinutes += minutes;
      }
    }

    DateTime? maxDay;
    double? maxValue; // 0~100
    dayFocus.forEach((day, agg) {
      if (agg.focusWeightMinutes <= 0) return;
      final v = (agg.focusWeightedSum / agg.focusWeightMinutes) * 100;
      if (maxValue == null || v > maxValue!) {
        maxValue = double.parse(v.toStringAsFixed(1));
        maxDay = day;
      }
    });

    final buckets = cells.values
        .map((a) => DaySubjectBucket(
              day: a.day!,
              subjectId: a.subjectId!,
              subjectName: a.subjectName!,
              subjectColor: a.subjectColor!,
              minutes: a.minutes,
            ))
        .toList()
      ..sort((x, y) {
        final dCmp = x.day.compareTo(y.day);
        if (dCmp != 0) return dCmp;
        return x.subjectId.compareTo(y.subjectId);
      });

    final completedTodos =
        (todoRows.first['done_count'] as num? ?? 0).toInt();

    return WeeklyReport(
      buckets: buckets,
      totalMinutes: totalMinutes,
      completedTodos: completedTodos,
      maxFocusDay: maxDay,
      maxFocusValue: maxValue,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  FutureProvider.family — UI 에서 ref.watch(dailyReportProvider(date)) 식으로 사용.
// ───────────────────────────────────────────────────────────────────────────

final dailyHourlyBucketsProvider =
    FutureProvider.family<List<HourlyBucket>, DateTime>((ref, date) async {
  final helper = ref.read(databaseHelperProvider);
  final db = await helper.database;
  return ReportQueries.getDailyHourlyBuckets(db, date);
});

final dailyReportProvider =
    FutureProvider.family<DailyReport, DateTime>((ref, date) async {
  final helper = ref.read(databaseHelperProvider);
  final db = await helper.database;
  return ReportQueries.getDailyReport(db, date);
});

final dailyModeRatioProvider =
    FutureProvider.family<ModeRatio, DateTime>((ref, date) async {
  final helper = ref.read(databaseHelperProvider);
  final db = await helper.database;
  return ReportQueries.getDailyModeRatio(db, date);
});

final dailyActivitiesProvider =
    FutureProvider.family<List<ActivityEntry>, DateTime>((ref, date) async {
  final helper = ref.read(databaseHelperProvider);
  final db = await helper.database;
  return ReportQueries.getDailyActivities(db, date);
});

final weeklyReportProvider =
    FutureProvider.family<WeeklyReport, DateTime>((ref, weekStart) async {
  final helper = ref.read(databaseHelperProvider);
  final db = await helper.database;
  return ReportQueries.getWeeklyReport(db, weekStart);
});

// ───────────────────────────────────────────────────────────────────────────
//  내부 유틸
// ───────────────────────────────────────────────────────────────────────────

class _DateBounds {
  final int startMs;
  final int endMs;
  const _DateBounds(this.startMs, this.endMs);

  factory _DateBounds.day(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _DateBounds(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  factory _DateBounds.week(DateTime weekStart) {
    final start =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return _DateBounds(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }
}

class _BucketAgg {
  int? hour;
  DateTime? day;
  String? subjectId;
  String? subjectName;
  int? subjectColor;
  int minutes = 0;
  double focusWeightedSum = 0;
  int focusWeightMinutes = 0;

  _BucketAgg({
    this.hour,
    this.day,
    this.subjectId,
    this.subjectName,
    this.subjectColor,
  });
}
