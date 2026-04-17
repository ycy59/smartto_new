import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_provider.dart';

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
