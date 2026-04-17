import '../entities/study_session.dart';

abstract class StudySessionRepository {
  Future<List<StudySession>> getByGoal(String goalId);
  Future<List<StudySession>> getByDateRange(DateTime from, DateTime to);
  Future<void> save(StudySession session);
  Future<void> update(StudySession session);
}
