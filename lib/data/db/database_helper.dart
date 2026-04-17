import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static const String _dbName = 'smartto.db';
  static const int _dbVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE subjects (
          id    TEXT PRIMARY KEY,
          name  TEXT NOT NULL,
          color INTEGER NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE study_goals (
          id                  TEXT    PRIMARY KEY,
          subject_id          TEXT    NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
          title               TEXT    NOT NULL,
          mode                TEXT    NOT NULL DEFAULT 'study',
          understanding_level TEXT    NOT NULL DEFAULT 'normal',
          due_date            INTEGER,
          stability           REAL    NOT NULL DEFAULT 1.0,
          difficulty          REAL    NOT NULL DEFAULT 5.0,
          retrievability      REAL    NOT NULL DEFAULT 1.0,
          repetitions         INTEGER NOT NULL DEFAULT 0,
          state               TEXT    NOT NULL DEFAULT 'new',
          last_review         INTEGER,
          next_due            INTEGER NOT NULL,
          created_at          INTEGER NOT NULL
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_goals_next_due  ON study_goals(next_due)',
      );
      await txn.execute(
        'CREATE INDEX idx_goals_subject   ON study_goals(subject_id)',
      );

      await txn.execute('''
        CREATE TABLE todo_items (
          id        TEXT    PRIMARY KEY,
          goal_id   TEXT    NOT NULL REFERENCES study_goals(id) ON DELETE CASCADE,
          text      TEXT    NOT NULL,
          is_done   INTEGER NOT NULL DEFAULT 0,
          position  INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_todos_goal ON todo_items(goal_id)',
      );

      await txn.execute('''
        CREATE TABLE study_sessions (
          id               TEXT    PRIMARY KEY,
          goal_id          TEXT    NOT NULL REFERENCES study_goals(id) ON DELETE CASCADE,
          started_at       INTEGER NOT NULL,
          ended_at         INTEGER,
          focus_score      REAL,
          duration_minutes INTEGER,
          created_at       INTEGER NOT NULL
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_sessions_goal    ON study_sessions(goal_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_sessions_started ON study_sessions(started_at)',
      );
    });
  }

  // ── CRUD 헬퍼 ──────────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
