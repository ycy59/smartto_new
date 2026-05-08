import '../entities/subject.dart';

abstract class SubjectRepository {
  Future<List<Subject>> getAll();
  Future<Subject?> getById(String id);
  Future<void> save(Subject subject);
  Future<void> delete(String id);
}
