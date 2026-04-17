import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../algorithms/fsrs/fsrs_engine.dart';
import '../domain/entities/study_goal.dart';
import '../domain/entities/todo_item.dart';
import 'database_provider.dart';

const _uuid = Uuid();

/// 특정 과목의 학습 목표 목록
final goalsBySubjectProvider =
    AsyncNotifierProviderFamily<GoalsBySubjectNotifier, List<StudyGoal>, String>(
  GoalsBySubjectNotifier.new,
);

class GoalsBySubjectNotifier
    extends FamilyAsyncNotifier<List<StudyGoal>, String> {
  @override
  Future<List<StudyGoal>> build(String subjectId) async {
    return ref.read(studyGoalRepoProvider).getBySubject(subjectId);
  }

  /// 새 학습 목표 추가 (할일 + FSRS 초기화)
  Future<void> add({
    required String subjectId,
    required String title,
    required StudyMode mode,
    required UnderstandingLevel understandingLevel,
    DateTime? dueDate,
    List<String> todoTexts = const [],
  }) async {
    final levelStr = understandingLevel.toDbString();
    final fsrs = FsrsEngine.initFromLevel(levelStr);

    final goal = StudyGoal(
      id: _uuid.v4(),
      subjectId: subjectId,
      title: title,
      mode: mode,
      understandingLevel: understandingLevel,
      dueDate: dueDate,
      stability: fsrs.stability,
      difficulty: fsrs.difficulty,
      retrievability: fsrs.retrievability,
      repetitions: fsrs.repetitions,
      state: fsrs.state,
      lastReview: fsrs.lastReview,
      nextDue: fsrs.nextDue,
      createdAt: DateTime.now(),
    );

    await ref.read(studyGoalRepoProvider).save(goal);

    if (todoTexts.isNotEmpty) {
      final todos = todoTexts.asMap().entries.map((e) => TodoItem(
            id: _uuid.v4(),
            goalId: goal.id,
            text: e.value,
            isDone: false,
            position: e.key,
          ));
      await ref.read(todoRepoProvider).saveAll(todos.toList());
    }

    ref.invalidateSelf();
  }

  /// 세션 종료 후 집중도 점수로 FSRS 업데이트
  Future<void> applyFocusScore(StudyGoal goal, double focusScore) async {
    final result = FsrsEngine.review(
      stability: goal.stability,
      difficulty: goal.difficulty,
      repetitions: goal.repetitions,
      lastReview: goal.lastReview,
      focusScore: focusScore,
    );

    final updated = goal.copyWith(
      stability: result.stability,
      difficulty: result.difficulty,
      retrievability: result.retrievability,
      repetitions: result.repetitions,
      state: result.state,
      lastReview: () => result.lastReview,
      nextDue: result.nextDue,
    );

    await ref.read(studyGoalRepoProvider).updateFsrs(updated);
    ref.invalidateSelf();
  }

  Future<void> delete(String goalId) async {
    await ref.read(studyGoalRepoProvider).delete(goalId);
    ref.invalidateSelf();
  }
}
