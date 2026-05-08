import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static const String _dbName = 'smartto.db';
  static const int _dbVersion = 4;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = kIsWeb
        ? _dbName
        : p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  /// 테스트용: in-memory DB 인스턴스를 새로 만들어 반환.
  /// 싱글턴 [instance]와 분리되며, 호출자가 [Database.close]로 종료.
  static Future<Database> openInMemory() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: _dbVersion,
      onCreate: (db, _) => instance._onCreate(db, _dbVersion),
      onUpgrade: (db, o, n) => instance._onUpgrade(db, o, n),
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
          id           TEXT    PRIMARY KEY,
          goal_id      TEXT    NOT NULL REFERENCES study_goals(id) ON DELETE CASCADE,
          text         TEXT    NOT NULL,
          is_done      INTEGER NOT NULL DEFAULT 0,
          position     INTEGER NOT NULL DEFAULT 0,
          priority     INTEGER NOT NULL DEFAULT 0,
          mode         TEXT    NOT NULL DEFAULT 'study',
          due_date     INTEGER,
          completed_at INTEGER
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_todos_goal ON todo_items(goal_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_todos_completed_at ON todo_items(completed_at)',
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE todo_items ADD COLUMN priority INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE todo_items ADD COLUMN mode TEXT NOT NULL DEFAULT 'study'",
      );
      await db.execute(
        'ALTER TABLE todo_items ADD COLUMN due_date INTEGER',
      );
    }
    if (oldVersion < 4) {
      // 리포트의 "오늘 완료한 todo" 집계를 위해 완료 시각 추가.
      // 기존 is_done=1 데이터는 completed_at이 NULL → 일자별 집계에서 자연스럽게 제외됨.
      await db.execute(
        'ALTER TABLE todo_items ADD COLUMN completed_at INTEGER',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_todos_completed_at ON todo_items(completed_at)',
      );
    }
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
