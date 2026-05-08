import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/study_session.dart';
import 'calendar_provider.dart';
import 'database_provider.dart';
import 'stats_provider.dart';
import 'study_goal_provider.dart';
import 'today_plan_provider.dart';

const _uuid = Uuid();

final studySessionProvider =
    AsyncNotifierProvider<StudySessionNotifier, List<StudySession>>(
  StudySessionNotifier.new,
);

class StudySessionNotifier extends AsyncNotifier<List<StudySession>> {
  @override
  Future<List<StudySession>> build() async => [];

  /// 세션 시작 — DB에 시작 시각 기록
  Future<StudySession> startSession(String goalId) async {
    final session = StudySession(
      id: _uuid.v4(),
      goalId: goalId,
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await ref.read(studySessionRepoProvider).save(session);
    return session;
  }

  /// 세션 종료 — 집중도 점수 저장 후 FSRS 업데이트
  ///
  /// [focusScore] 입력 단위는 0.0 ~ 1.0 (ConcentrationService.averageScore01).
  /// study_sessions.focus_score 컬럼에는 0~1 그대로 저장하고, FSRS 엔진에는
  /// *100 한 0~100 스케일을 넘긴다 (FsrsRating.fromFocusScore 와 일관).
  Future<void> endSession({
    required StudySession session,
    required double focusScore, // 0.0 ~ 1.0 (ConcentrationService 출력)
    required String subjectId,
  }) async {
    final now = DateTime.now();
    final durationMinutes =
        now.difference(session.startedAt).inMinutes;
    // FSRS 엔진은 0~100 스케일을 기대하므로 변환.
    final focusPercent = (focusScore * 100).clamp(0.0, 100.0);

    final updated = session.copyWith(
      endedAt: () => now,
      focusScore: () => focusScore, // DB 에는 0~1 그대로 저장
      durationMinutes: () => durationMinutes,
    );
    await ref.read(studySessionRepoProvider).update(updated);

    // 0~100 스케일로 FSRS 업데이트
    final goal = await ref.read(studyGoalRepoProvider).getById(session.goalId);
    if (goal != null) {
      await ref
          .read(goalsBySubjectProvider(subjectId).notifier)
          .applyFocusScore(goal, focusPercent);
    }

    // 오늘 계획 + 통계 + 캘린더(FSRS next_due 변경 반영) 갱신
    ref.read(todayPlanProvider.notifier).refresh();
    ref.read(statsProvider.notifier).refresh();
    ref.invalidate(calendarMonthDataProvider);
  }
}
