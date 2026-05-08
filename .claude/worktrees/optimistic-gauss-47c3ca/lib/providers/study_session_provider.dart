import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/study_session.dart';
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
  Future<void> endSession({
    required StudySession session,
    required double focusScore, // 0.0 ~ 1.0 (MediaPipe 출력)
    required String subjectId,
  }) async {
    final now = DateTime.now();
    final durationMinutes =
        now.difference(session.startedAt).inMinutes;
    final focusPercent = (focusScore * 100).clamp(0.0, 100.0);

    final updated = session.copyWith(
      endedAt: () => now,
      focusScore: () => focusScore,
      durationMinutes: () => durationMinutes,
    );
    await ref.read(studySessionRepoProvider).update(updated);

    // 집중도 점수로 FSRS 업데이트
    final goal = await ref.read(studyGoalRepoProvider).getById(session.goalId);
    if (goal != null) {
      await ref
          .read(goalsBySubjectProvider(subjectId).notifier)
          .applyFocusScore(goal, focusPercent);
    }

    // 오늘 계획 + 통계 갱신
    ref.read(todayPlanProvider.notifier).refresh();
    ref.read(statsProvider.notifier).refresh();
  }
}
