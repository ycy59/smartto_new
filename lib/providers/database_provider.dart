import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db/database_helper.dart';
import '../data/repositories/subject_repository_impl.dart';
import '../data/repositories/study_goal_repository_impl.dart';
import '../data/repositories/study_session_repository_impl.dart';
import '../data/repositories/todo_repository_impl.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final subjectRepoProvider = Provider((ref) {
  return SubjectRepositoryImpl(ref.read(databaseHelperProvider));
});

final studyGoalRepoProvider = Provider((ref) {
  return StudyGoalRepositoryImpl(ref.read(databaseHelperProvider));
});

final studySessionRepoProvider = Provider((ref) {
  return StudySessionRepositoryImpl(ref.read(databaseHelperProvider));
});

final todoRepoProvider = Provider((ref) {
  return TodoRepositoryImpl(ref.read(databaseHelperProvider));
});
