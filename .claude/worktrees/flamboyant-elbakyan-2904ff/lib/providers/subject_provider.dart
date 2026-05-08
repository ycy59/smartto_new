import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/subject.dart';
import 'database_provider.dart';
import 'stats_provider.dart';
import 'today_plan_provider.dart';

const _uuid = Uuid();

final subjectListProvider =
    AsyncNotifierProvider<SubjectNotifier, List<Subject>>(SubjectNotifier.new);

class SubjectNotifier extends AsyncNotifier<List<Subject>> {
  @override
  Future<List<Subject>> build() async {
    return ref.read(subjectRepoProvider).getAll();
  }

  Future<Subject> add({required String name, required Color color}) async {
    final subject = Subject(
      id: _uuid.v4(),
      name: name,
      color: color,
    );
    await ref.read(subjectRepoProvider).save(subject);
    ref.invalidateSelf();
    // 새 과목이 생기면 오늘 계획·통계도 영향을 받을 수 있음
    ref.read(todayPlanProvider.notifier).refresh();
    ref.read(statsProvider.notifier).refresh();
    return subject;
  }

  Future<void> delete(String id) async {
    await ref.read(subjectRepoProvider).delete(id);
    ref.invalidateSelf();
    // ON DELETE CASCADE 로 study_goals/todo_items/study_sessions 모두 사라지므로
    // 관련 화면 데이터도 함께 무효화.
    ref.read(todayPlanProvider.notifier).refresh();
    ref.read(statsProvider.notifier).refresh();
  }
}
