import '../../domain/entities/subject.dart';
import '../../domain/repositories/subject_repository.dart';
import '../db/database_helper.dart';

class SubjectRepositoryImpl implements SubjectRepository {
  final DatabaseHelper _db;
  SubjectRepositoryImpl(this._db);

  @override
  Future<List<Subject>> getAll() async {
    final rows = await _db.query('subjects', orderBy: 'rowid ASC');
    return rows.map(Subject.fromMap).toList();
  }

  @override
  Future<Subject?> getById(String id) async {
    final rows =
        await _db.query('subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Subject.fromMap(rows.first);
  }

  @override
  Future<void> save(Subject subject) async {
    await _db.insert('subjects', subject.toMap());
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }
}
