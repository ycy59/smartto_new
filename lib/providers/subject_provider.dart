import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/subject.dart';
import 'database_provider.dart';

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
    return subject;
  }

  Future<void> delete(String id) async {
    await ref.read(subjectRepoProvider).delete(id);
    ref.invalidateSelf();
  }
}
