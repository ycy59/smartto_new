import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 로컬 SQLite 데이터베이스
//
// 테이블:
//   sessions    - 포모도로 세션 기록
//   focus_logs  - 초 단위 집중도 로그
// ─────────────────────────────────────────────────────────────────────────────

class LocalDb {
  static final LocalDb _instance = LocalDb._();
  static LocalDb get instance => _instance;
  LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'smartto.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            subject     TEXT,
            task        TEXT,
            started_at  INTEGER NOT NULL,   -- Unix timestamp (ms)
            ended_at    INTEGER,
            duration_s  INTEGER,            -- 실제 진행 시간 (초)
            avg_score   REAL,               -- 평균 집중도 점수 (0~100)
            focused_pct REAL                -- 집중 상태 비율 (0~1)
          )
        ''');

        await db.execute('''
          CREATE TABLE focus_logs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id  INTEGER NOT NULL,
            ts          INTEGER NOT NULL,   -- Unix timestamp (ms)
            score       REAL,
            status      TEXT,              -- 'focused' | 'drowsy' | 'distracted'
            ear         REAL,
            mar         REAL,
            yaw         REAL,
            FOREIGN KEY (session_id) REFERENCES sessions(id)
          )
        ''');
      },
    );
  }

  // ── 세션 ────────────────────────────────────────────────────────────────

  /// 새 세션 시작 → session id 반환
  Future<int> startSession({String? subject, String? task}) async {
    final database = await db;
    return database.insert('sessions', {
      'subject':    subject,
      'task':       task,
      'started_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 세션 종료 (평균 점수 계산 포함)
  Future<void> endSession(int sessionId) async {
    final database = await db;

    // 해당 세션의 focus_logs 집계
    final logs = await database.query(
      'focus_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    if (logs.isEmpty) {
      await database.update(
        'sessions',
        {'ended_at': DateTime.now().millisecondsSinceEpoch, 'duration_s': 0},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return;
    }

    final scores     = logs.map((l) => (l['score'] as num).toDouble()).toList();
    final avgScore   = scores.reduce((a, b) => a + b) / scores.length;
    final focusedCnt = logs.where((l) => l['status'] == 'focused').length;
    final focusedPct = focusedCnt / logs.length;

    final started = await database.query(
      'sessions',
      columns: ['started_at'],
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    final startedAt = started.first['started_at'] as int;
    final endedAt   = DateTime.now().millisecondsSinceEpoch;

    await database.update(
      'sessions',
      {
        'ended_at':    endedAt,
        'duration_s':  (endedAt - startedAt) ~/ 1000,
        'avg_score':   avgScore,
        'focused_pct': focusedPct,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// 최근 세션 목록
  Future<List<Map<String, dynamic>>> recentSessions({int limit = 20}) async {
    final database = await db;
    return database.query(
      'sessions',
      where: 'ended_at IS NOT NULL',
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }

  // ── 집중도 로그 ──────────────────────────────────────────────────────────

  /// 집중도 포인트 기록 (2초마다 호출)
  Future<void> logFocus({
    required int    sessionId,
    required double score,
    required String status,
    double ear = 0,
    double mar = 0,
    double yaw = 0,
  }) async {
    final database = await db;
    await database.insert('focus_logs', {
      'session_id': sessionId,
      'ts':         DateTime.now().millisecondsSinceEpoch,
      'score':      score,
      'status':     status,
      'ear':        ear,
      'mar':        mar,
      'yaw':        yaw,
    });
  }

  /// 특정 세션의 집중도 로그
  Future<List<Map<String, dynamic>>> logsForSession(int sessionId) async {
    final database = await db;
    return database.query(
      'focus_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'ts ASC',
    );
  }

  /// 오늘 총 집중 시간 (초)
  Future<int> todayFocusedSeconds() async {
    final database = await db;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day)
        .millisecondsSinceEpoch;

    final rows = await database.rawQuery('''
      SELECT SUM(duration_s) as total
      FROM sessions
      WHERE started_at >= ? AND ended_at IS NOT NULL
    ''', [startOfDay]);

    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  /// 오늘 완료한 세션 수
  Future<int> todaySessionCount() async {
    final database = await db;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day)
        .millisecondsSinceEpoch;

    final rows = await database.rawQuery('''
      SELECT COUNT(*) as cnt
      FROM sessions
      WHERE started_at >= ? AND ended_at IS NOT NULL
    ''', [startOfDay]);

    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// 이번 주 평균 집중도
  Future<double> weeklyAvgScore() async {
    final database = await db;
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1)
        .millisecondsSinceEpoch;

    final rows = await database.rawQuery('''
      SELECT AVG(avg_score) as avg
      FROM sessions
      WHERE started_at >= ? AND avg_score IS NOT NULL
    ''', [startOfWeek]);

    return (rows.first['avg'] as num?)?.toDouble() ?? 0.0;
  }
}
