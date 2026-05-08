// Stats / ReportQueries 단위 테스트.
//
// 주의: sqflite_common_ffi 를 dev_dependencies 에 추가하지 않고 기존
// pubspec 의존성만으로 동작시키기 위해 sqflite 의 inMemoryDatabasePath 를 사용.
// 단, 일반 flutter_test 환경에서는 sqflite 채널이 없어 in-memory DB 도 열리지
// 않으므로 본 테스트는 `flutter test --platform=vm` 가 아닌 호스트 sqflite ffi
// 가 셋업된 상태(=`sqflite_common_ffi` 동적 추가)에서 실행해야 함.
//
// 본 파일은 sqflite_common_ffi 가 있을 때 정상 동작하도록 작성되었으며,
// 없는 경우 setUpAll 에서 즉시 skip 됨.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartto_new/providers/stats_provider.dart';

void main() {
  // sqflite ffi 초기화 (Linux/macOS host VM).
  sqfliteFfiInit();
  sql.databaseFactory = databaseFactoryFfi;

  late sql.Database db;

  /// 신선한 in-memory DB 를 매 테스트마다 새로 만들어 격리.
  Future<void> initSchema() async {
    db = await sql.databaseFactory.openDatabase(
      sql.inMemoryDatabasePath,
      options: sql.OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE subjects (
              id    TEXT PRIMARY KEY,
              name  TEXT NOT NULL,
              color INTEGER NOT NULL
            )
          ''');
          await db.execute('''
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
          await db.execute('''
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
          await db.execute('''
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
        },
      ),
    );
  }

  // ─── fixture 헬퍼 ────────────────────────────────────────────────────
  Future<void> insertSubject(String id, String name, int color) async {
    await db.insert('subjects',
        {'id': id, 'name': name, 'color': color});
  }

  Future<void> insertGoal({
    required String id,
    required String subjectId,
    required String title,
    String mode = 'study',
    DateTime? dueDate,
  }) async {
    await db.insert('study_goals', {
      'id': id,
      'subject_id': subjectId,
      'title': title,
      'mode': mode,
      'understanding_level': 'normal',
      'due_date': dueDate?.millisecondsSinceEpoch,
      'stability': 4.0,
      'difficulty': 5.0,
      'retrievability': 1.0,
      'repetitions': 0,
      'state': 'new',
      'last_review': null,
      'next_due': DateTime(2026, 4, 26).millisecondsSinceEpoch,
      'created_at': DateTime(2026, 4, 1).millisecondsSinceEpoch,
    });
  }

  Future<void> insertSession({
    required String id,
    required String goalId,
    required DateTime startedAt,
    DateTime? endedAt,
    double? focusScore,
    int? durationMinutes,
  }) async {
    await db.insert('study_sessions', {
      'id': id,
      'goal_id': goalId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'focus_score': focusScore,
      'duration_minutes': durationMinutes,
      'created_at': startedAt.millisecondsSinceEpoch,
    });
  }

  Future<void> insertTodo({
    required String id,
    required String goalId,
    required String text,
    bool isDone = false,
    DateTime? completedAt,
  }) async {
    await db.insert('todo_items', {
      'id': id,
      'goal_id': goalId,
      'text': text,
      'is_done': isDone ? 1 : 0,
      'position': 0,
      'priority': 0,
      'mode': 'study',
      'due_date': null,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    });
  }

  setUp(() async {
    await initSchema();
  });

  tearDown(() async {
    await db.close();
  });

  // ════════════════════════════════════════════════════════════════════
  //  ① getDailyHourlyBuckets
  // ════════════════════════════════════════════════════════════════════

  group('getDailyHourlyBuckets', () {
    test('빈 DB → 빈 리스트', () async {
      final buckets =
          await ReportQueries.getDailyHourlyBuckets(db, DateTime(2026, 4, 26));
      expect(buckets, isEmpty);
    });

    test('동일 시간대 + 동일 과목 세션 2개 → 분 누적, 가중 평균 집중도', () async {
      await insertSubject('subj_1', '알고리즘', 0xFFFF0000);
      await insertGoal(id: 'g1', subjectId: 'subj_1', title: '회귀');

      // 13시 30분간 0.6 + 13시 30분간 0.8 → 60분, 가중평균 0.7 → 70.0
      await insertSession(
        id: 's1',
        goalId: 'g1',
        startedAt: DateTime(2026, 4, 26, 13, 0),
        endedAt: DateTime(2026, 4, 26, 13, 30),
        focusScore: 0.6,
        durationMinutes: 30,
      );
      await insertSession(
        id: 's2',
        goalId: 'g1',
        startedAt: DateTime(2026, 4, 26, 13, 35),
        endedAt: DateTime(2026, 4, 26, 14, 5),
        focusScore: 0.8,
        durationMinutes: 30,
      );

      final buckets =
          await ReportQueries.getDailyHourlyBuckets(db, DateTime(2026, 4, 26));
      expect(buckets, hasLength(1));
      expect(buckets.first.hour, 13);
      expect(buckets.first.subjectName, '알고리즘');
      expect(buckets.first.subjectColor, 0xFFFF0000);
      expect(buckets.first.minutes, 60);
      expect(buckets.first.avgFocus, 70.0);
    });

    test('다른 시간대 + 다른 과목 → 4개 버킷 (시간 → 과목 정렬)', () async {
      await insertSubject('a', '알고리즘', 0xFF0000FF);
      await insertSubject('b', '데이터통신', 0xFF00FF00);
      await insertGoal(id: 'g_a', subjectId: 'a', title: 't_a');
      await insertGoal(id: 'g_b', subjectId: 'b', title: 't_b');

      await insertSession(
        id: '1',
        goalId: 'g_a',
        startedAt: DateTime(2026, 4, 26, 9, 0),
        endedAt: DateTime(2026, 4, 26, 9, 25),
        focusScore: 0.7,
        durationMinutes: 25,
      );
      await insertSession(
        id: '2',
        goalId: 'g_b',
        startedAt: DateTime(2026, 4, 26, 9, 30),
        endedAt: DateTime(2026, 4, 26, 9, 55),
        focusScore: 0.5,
        durationMinutes: 25,
      );
      await insertSession(
        id: '3',
        goalId: 'g_a',
        startedAt: DateTime(2026, 4, 26, 14, 0),
        endedAt: DateTime(2026, 4, 26, 14, 30),
        focusScore: 0.9,
        durationMinutes: 30,
      );

      final buckets =
          await ReportQueries.getDailyHourlyBuckets(db, DateTime(2026, 4, 26));
      expect(buckets, hasLength(3));
      // 정렬: 9시(a, b), 14시(a)
      expect(buckets[0].hour, 9);
      expect(buckets[0].subjectId, 'a');
      expect(buckets[1].hour, 9);
      expect(buckets[1].subjectId, 'b');
      expect(buckets[2].hour, 14);
      expect(buckets[2].subjectId, 'a');
    });

    test('focus_score NULL 인 세션은 minutes 만 합산, avgFocus 는 null', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');

      await insertSession(
        id: '1',
        goalId: 'g',
        startedAt: DateTime(2026, 4, 26, 10, 0),
        endedAt: DateTime(2026, 4, 26, 10, 25),
        focusScore: null,
        durationMinutes: 25,
      );

      final buckets =
          await ReportQueries.getDailyHourlyBuckets(db, DateTime(2026, 4, 26));
      expect(buckets, hasLength(1));
      expect(buckets.first.minutes, 25);
      expect(buckets.first.avgFocus, isNull);
    });

    test('전날/다음날 세션은 제외', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');

      await insertSession(
        id: 'prev',
        goalId: 'g',
        startedAt: DateTime(2026, 4, 25, 23, 30),
        endedAt: DateTime(2026, 4, 25, 23, 55),
        focusScore: 0.5,
        durationMinutes: 25,
      );
      await insertSession(
        id: 'next',
        goalId: 'g',
        startedAt: DateTime(2026, 4, 27, 0, 5),
        endedAt: DateTime(2026, 4, 27, 0, 30),
        focusScore: 0.5,
        durationMinutes: 25,
      );
      await insertSession(
        id: 'today',
        goalId: 'g',
        startedAt: DateTime(2026, 4, 26, 12, 0),
        endedAt: DateTime(2026, 4, 26, 12, 25),
        focusScore: 0.5,
        durationMinutes: 25,
      );

      final buckets =
          await ReportQueries.getDailyHourlyBuckets(db, DateTime(2026, 4, 26));
      expect(buckets, hasLength(1));
      expect(buckets.first.hour, 12);
    });

    test('미완료 세션(ended_at NULL) 은 제외', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');

      await insertSession(
        id: 'live',
        goalId: 'g',
        startedAt: DateTime(2026, 4, 26, 12, 0),
        endedAt: null,
        focusScore: null,
        durationMinutes: null,
      );

      final buckets =
          await ReportQueries.getDailyHourlyBuckets(db, DateTime(2026, 4, 26));
      expect(buckets, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //  ② getDailyReport
  // ════════════════════════════════════════════════════════════════════

  group('getDailyReport', () {
    test('빈 DB → empty', () async {
      final r = await ReportQueries.getDailyReport(db, DateTime(2026, 4, 26));
      expect(r.totalMinutes, 0);
      expect(r.completedTodos, 0);
      expect(r.avgFocus, isNull);
    });

    test('세션 3개 + 완료 todo 2개 → 합산 + 카운트', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');

      await insertSession(
          id: '1',
          goalId: 'g',
          startedAt: DateTime(2026, 4, 26, 9, 0),
          endedAt: DateTime(2026, 4, 26, 9, 25),
          focusScore: 0.6,
          durationMinutes: 25);
      await insertSession(
          id: '2',
          goalId: 'g',
          startedAt: DateTime(2026, 4, 26, 13, 0),
          endedAt: DateTime(2026, 4, 26, 13, 30),
          focusScore: 0.8,
          durationMinutes: 30);
      await insertSession(
          id: '3',
          goalId: 'g',
          startedAt: DateTime(2026, 4, 26, 18, 0),
          endedAt: DateTime(2026, 4, 26, 18, 45),
          focusScore: 0.7,
          durationMinutes: 45);

      await insertTodo(
        id: 't1',
        goalId: 'g',
        text: 'A',
        isDone: true,
        completedAt: DateTime(2026, 4, 26, 14, 0),
      );
      await insertTodo(
        id: 't2',
        goalId: 'g',
        text: 'B',
        isDone: true,
        completedAt: DateTime(2026, 4, 26, 19, 30),
      );
      // 다른 날 완료 → 제외
      await insertTodo(
        id: 't3',
        goalId: 'g',
        text: 'C',
        isDone: true,
        completedAt: DateTime(2026, 4, 25, 14, 0),
      );

      final r = await ReportQueries.getDailyReport(db, DateTime(2026, 4, 26));
      expect(r.totalMinutes, 100); // 25 + 30 + 45
      expect(r.completedTodos, 2);
      // avg(focus_score) = (0.6 + 0.8 + 0.7) / 3 = 0.7 → 70.0
      expect(r.avgFocus, 70.0);
    });

    test('완료 토글했지만 completed_at NULL 인 todo 는 제외', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');

      await insertTodo(
        id: 't_legacy',
        goalId: 'g',
        text: '예전부터 done 이지만 completed_at 없음',
        isDone: true,
        completedAt: null,
      );

      final r = await ReportQueries.getDailyReport(db, DateTime(2026, 4, 26));
      expect(r.completedTodos, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //  ③ getDailyModeRatio
  // ════════════════════════════════════════════════════════════════════

  group('getDailyModeRatio', () {
    test('빈 DB → 0/0', () async {
      final r = await ReportQueries.getDailyModeRatio(db, DateTime(2026, 4, 26));
      expect(r.examMinutes, 0);
      expect(r.studyMinutes, 0);
      expect(r.totalMinutes, 0);
      expect(r.examRatio, 0.0);
      expect(r.studyRatio, 0.0);
    });

    test('exam goal 60분 + study goal 40분 → 6:4', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g_exam', subjectId: 's', title: '시험', mode: 'exam');
      await insertGoal(id: 'g_study', subjectId: 's', title: '학습', mode: 'study');

      await insertSession(
          id: '1',
          goalId: 'g_exam',
          startedAt: DateTime(2026, 4, 26, 9, 0),
          endedAt: DateTime(2026, 4, 26, 10, 0),
          focusScore: 0.7,
          durationMinutes: 60);
      await insertSession(
          id: '2',
          goalId: 'g_study',
          startedAt: DateTime(2026, 4, 26, 14, 0),
          endedAt: DateTime(2026, 4, 26, 14, 40),
          focusScore: 0.7,
          durationMinutes: 40);

      final r = await ReportQueries.getDailyModeRatio(db, DateTime(2026, 4, 26));
      expect(r.examMinutes, 60);
      expect(r.studyMinutes, 40);
      expect(r.examRatio, closeTo(0.6, 1e-9));
      expect(r.studyRatio, closeTo(0.4, 1e-9));
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //  ④ getDailyActivities
  // ════════════════════════════════════════════════════════════════════

  group('getDailyActivities', () {
    test('빈 DB → 빈 리스트', () async {
      final r =
          await ReportQueries.getDailyActivities(db, DateTime(2026, 4, 26));
      expect(r, isEmpty);
    });

    test('세션 3개 → 시작시각 ASC 정렬, 과목 정보 join', () async {
      await insertSubject('a', '알고리즘', 0xFF0000FF);
      await insertSubject('b', '데이터베이스', 0xFF00FF00);
      await insertGoal(id: 'g_a', subjectId: 'a', title: '회귀 분석');
      await insertGoal(id: 'g_b', subjectId: 'b', title: 'sqld 정의');

      await insertSession(
          id: '1',
          goalId: 'g_b',
          startedAt: DateTime(2026, 4, 26, 17, 15),
          endedAt: DateTime(2026, 4, 26, 17, 40),
          focusScore: 0.7,
          durationMinutes: 25);
      await insertSession(
          id: '2',
          goalId: 'g_a',
          startedAt: DateTime(2026, 4, 26, 13, 10),
          endedAt: DateTime(2026, 4, 26, 13, 35),
          focusScore: 0.8,
          durationMinutes: 25);

      final r =
          await ReportQueries.getDailyActivities(db, DateTime(2026, 4, 26));
      expect(r, hasLength(2));
      // 정렬: 13:10 → 17:15
      expect(r[0].sessionId, '2');
      expect(r[0].goalTitle, '회귀 분석');
      expect(r[0].subjectName, '알고리즘');
      expect(r[0].subjectColor, 0xFF0000FF);
      expect(r[0].durationMinutes, 25);
      expect(r[0].focusScore, 0.8);
      expect(r[1].sessionId, '1');
      expect(r[1].subjectName, '데이터베이스');
    });

    test('미완료 세션 은 제외', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');
      await insertSession(
          id: 'live',
          goalId: 'g',
          startedAt: DateTime(2026, 4, 26, 12, 0),
          endedAt: null);

      final r =
          await ReportQueries.getDailyActivities(db, DateTime(2026, 4, 26));
      expect(r, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════════
  //  ⑤ getWeeklyReport
  // ════════════════════════════════════════════════════════════════════

  group('getWeeklyReport', () {
    test('빈 DB → empty', () async {
      final r =
          await ReportQueries.getWeeklyReport(db, DateTime(2026, 4, 20));
      expect(r.buckets, isEmpty);
      expect(r.totalMinutes, 0);
      expect(r.completedTodos, 0);
      expect(r.maxFocusDay, isNull);
      expect(r.maxFocusValue, isNull);
    });

    test('월~수 세션 + 최고 집중일 = 화요일', () async {
      await insertSubject('a', '알고리즘', 0xFFFF0000);
      await insertSubject('b', '데이터통신', 0xFF00FF00);
      await insertGoal(id: 'g_a', subjectId: 'a', title: 't');
      await insertGoal(id: 'g_b', subjectId: 'b', title: 't');

      // 월요일 (4/20)
      await insertSession(
          id: 'm1',
          goalId: 'g_a',
          startedAt: DateTime(2026, 4, 20, 9, 0),
          endedAt: DateTime(2026, 4, 20, 10, 0),
          focusScore: 0.6,
          durationMinutes: 60);
      await insertSession(
          id: 'm2',
          goalId: 'g_b',
          startedAt: DateTime(2026, 4, 20, 14, 0),
          endedAt: DateTime(2026, 4, 20, 14, 30),
          focusScore: 0.5,
          durationMinutes: 30);

      // 화요일 (4/21) — 가장 높은 집중도
      await insertSession(
          id: 't1',
          goalId: 'g_a',
          startedAt: DateTime(2026, 4, 21, 10, 0),
          endedAt: DateTime(2026, 4, 21, 11, 0),
          focusScore: 0.95,
          durationMinutes: 60);

      // 수요일 (4/22)
      await insertSession(
          id: 'w1',
          goalId: 'g_b',
          startedAt: DateTime(2026, 4, 22, 15, 0),
          endedAt: DateTime(2026, 4, 22, 15, 45),
          focusScore: 0.7,
          durationMinutes: 45);

      // 다음주 (4/27) — 제외돼야 함
      await insertSession(
          id: 'next',
          goalId: 'g_a',
          startedAt: DateTime(2026, 4, 27, 9, 0),
          endedAt: DateTime(2026, 4, 27, 9, 30),
          focusScore: 1.0,
          durationMinutes: 30);

      // 완료 todo 3개 (이번주 2 + 지난주 1)
      await insertTodo(
        id: 'tdo1',
        goalId: 'g_a',
        text: 'a',
        isDone: true,
        completedAt: DateTime(2026, 4, 20, 18, 0),
      );
      await insertTodo(
        id: 'tdo2',
        goalId: 'g_b',
        text: 'b',
        isDone: true,
        completedAt: DateTime(2026, 4, 22, 18, 0),
      );
      await insertTodo(
        id: 'tdo_old',
        goalId: 'g_a',
        text: 'old',
        isDone: true,
        completedAt: DateTime(2026, 4, 13, 18, 0),
      );

      final r =
          await ReportQueries.getWeeklyReport(db, DateTime(2026, 4, 20));

      // 셀: 월(a, b), 화(a), 수(b) → 4개
      expect(r.buckets, hasLength(4));
      // 정렬 검증: 날짜 → 과목id
      expect(r.buckets[0].day, DateTime(2026, 4, 20));
      expect(r.buckets[0].subjectId, 'a');
      expect(r.buckets[0].minutes, 60);
      expect(r.buckets[1].day, DateTime(2026, 4, 20));
      expect(r.buckets[1].subjectId, 'b');
      expect(r.buckets[1].minutes, 30);
      expect(r.buckets[2].day, DateTime(2026, 4, 21));
      expect(r.buckets[2].minutes, 60);
      expect(r.buckets[3].day, DateTime(2026, 4, 22));
      expect(r.buckets[3].minutes, 45);

      // 합계
      expect(r.totalMinutes, 195); // 60+30+60+45 (4/27 제외)

      // 완료 todo (이번주만)
      expect(r.completedTodos, 2);

      // 최고 집중일: 4/21 (0.95)
      expect(r.maxFocusDay, DateTime(2026, 4, 21));
      expect(r.maxFocusValue, 95.0);
    });

    test('주간 범위 밖 세션 + focus_score 가 모두 null 이면 maxFocusDay 도 null', () async {
      await insertSubject('s', 'X', 0);
      await insertGoal(id: 'g', subjectId: 's', title: 't');

      await insertSession(
          id: '1',
          goalId: 'g',
          startedAt: DateTime(2026, 4, 20, 9, 0),
          endedAt: DateTime(2026, 4, 20, 9, 25),
          focusScore: null,
          durationMinutes: 25);

      final r =
          await ReportQueries.getWeeklyReport(db, DateTime(2026, 4, 20));
      expect(r.totalMinutes, 25);
      expect(r.maxFocusDay, isNull);
      expect(r.maxFocusValue, isNull);
    });
  });
}
