import '../entities/study_goal.dart';

abstract class StudyGoalRepository {
  Future<List<StudyGoal>> getAll();
  Future<List<StudyGoal>> getBySubject(String subjectId);
  Future<List<StudyGoal>> getDueToday();
  Future<StudyGoal?> getById(String id);
  Future<void> save(StudyGoal goal);
  Future<void> updateFsrs(StudyGoal goal);
  Future<void> delete(String id);
}
