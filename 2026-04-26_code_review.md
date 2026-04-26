# Smartto / smartto_new 코드 결함 리포트

> 검토일: 2026-04-26
> 검토 범위: `lib/algorithms`, `lib/data`, `lib/domain`, `lib/providers`,
> `lib/screens/{camera_page, main_screen}` 의 핵심 흐름
> 미검토: 1011줄짜리 `calendar_page.dart` (전체 더미), 1786줄짜리 `subject_page.dart` UI 로직 디테일

---

## 결함 분류 기준
- **🔴 Critical** — 시연·실제 사용 시 즉시 보이는 버그 또는 컴파일 실패
- **🟠 Major**  — 통계 정확성·데이터 일관성 손상
- **🟡 Minor**  — 코드 위생·미세 정확성·idiomatic 이슈

---

## 🔴 Critical 4건

### C1. `Color.toARGB32()` 가 Dart SDK 호환성을 깸
`lib/domain/entities/subject.dart`
```dart
'color': color.toARGB32(),
```
`Color.toARGB32()` 는 Flutter 3.27 / Dart SDK 3.6+ 에 추가된 신규 메서드. `pubspec.yaml` 의 `sdk: '>=3.0.0 <4.0.0'` 선언과 어긋남. 팀원 머신에 Flutter 3.24 이하가 깔려있으면 **`flutter pub get` 후 곧장 컴파일 실패**.

**수정**: `color.value` (deprecated 이지만 호환) 또는 SDK 하한을 `>=3.6.0` 으로 올림.

---

### C2. 카메라 페이지의 todo 토글이 DB 에 저장되지 않음
`lib/screens/camera_page.dart:70` 의 `_toggleDone()`:
```dart
void _toggleDone() {
  if (_selectedTask == null) return;
  setState(() {
    _doneMap[_selectedTask!.todoId] = !(_doneMap[_selectedTask!.todoId] ?? false);
  });
}
```
메모리 상의 `_doneMap` 만 갱신. `Navigator.pop` 으로 페이로드를 반환:
```dart
Navigator.pop(context, {
  'selectedTask': _selectedTask?.text,
  'doneMap': { ... },
});
```
호출자(`main_screen.dart:196`):
```dart
if (pageResult != null) {
  final selectedTask = pageResult['selectedTask'] as String?;
  ...
  // 주석: "DB 갱신은 camera_page 내부에서 완료됨"  ← 거짓
  _todayPlanKey.currentState?._loadTodayPlan();
}
```
**`pageResult['doneMap']` 을 무시함**. 결과적으로 카메라 페이지에서 todo 를 완료 처리해도 DB 에는 영영 반영되지 않음. 화면 닫고 돌아오면 미완료 상태로 복구됨.

**수정**: `_toggleDone` 안에서 `ref.read(todoRepoProvider).update(currentTodo.toggleDone(...))` 직접 호출 (UI 측 `_doneMap` 동기화는 그대로 두되 DB 도 같이 업데이트).

---

### C3. `markTaskDoneByText` 가 `completed_at` 을 안 찍음
`lib/screens/main_screen.dart:637`:
```dart
void markTaskDoneByText(String taskText, bool done) {
  setState(() {
    for (final subject in _subjects) {
      for (final todo in subject.todos) {
        if (todo.text.trim() == taskText.trim()) {
          todo.done = done;
          if (todo.id != null) {
            ref.read(todoRepoProvider).update(
                  todo._toDomain(subject.goalId!),
                );
          }
        }
      }
    }
  });
}
```
호출되는 `_toDomain` (line 914) 은 `completedAt` 인자를 안 넘김 → DB row 의 `completed_at` 이 NULL 로 들어감.

오늘 추가한 `dailyReportProvider.completedTodos` 는 `WHERE completed_at IS NOT NULL` 로 필터하므로, **이 경로로 토글한 todo 는 리포트 통계에 절대 안 잡힘**.

홈 화면 직접 토글(`today_plan_provider.toggleTodoDone`)만 `toggleDone()` 헬퍼로 stamp 됨. 즉 토글 경로 3 곳 중 1 곳만 정상.

**수정**: `MainPlanTodo._toDomain` 이 `done` 변경 시 `completedAt: () => done ? DateTime.now() : null` 을 같이 넘기도록 수정. 또는 `markTaskDoneByText` 가 `TodoItem.toggleDone()` 헬퍼를 거쳐가도록 변경.

---

### C4. 삭제 시 다른 provider 들이 stale 데이터를 들고 있음
`subject_provider.delete` / `study_goal_provider.delete` 모두 자기 자신만 `invalidateSelf()`:
```dart
Future<void> delete(String id) async {
  await ref.read(subjectRepoProvider).delete(id);
  ref.invalidateSelf();
}
```
SQLite 의 `ON DELETE CASCADE` 로 study_goals / todo_items / study_sessions 가 함께 삭제되지만, **그 사실을 다른 provider 들 (`todayPlanProvider`, `statsProvider`, `goalsBySubjectProvider`, 새 리포트 5종) 이 모름**.

시연 시나리오: 과목 삭제 → 홈 화면 "오늘의 계획" 카드에 그 과목이 잠시 남음 → 새로고침 후에야 사라짐. 더 나쁜 경우, 리포트 차트가 삭제된 과목 색상으로 그려져 있는데 데이터는 비어 있어 깨짐.

**수정**: 삭제 메서드에서 관련 provider 들도 `ref.invalidate(todayPlanProvider); ref.invalidate(statsProvider);` 호출.

---

## 🟠 Major 6건

### M1. "평균 집중도" 정의가 화면마다 다름
같은 라벨이 두 종류의 평균을 섞어 씀:

| 위치 | 정의 | 결과 |
|---|---|---|
| `statsProvider.weeklyAvgFocus` | SQL `AVG(focus_score)` | 세션 수 단순 평균 |
| `dailyReportProvider.avgFocus` (오늘 추가) | SQL `AVG(focus_score)` | 세션 수 단순 평균 |
| `getDailyHourlyBuckets.avgFocus` (오늘 추가) | `Σ(focus·minutes) / Σ(minutes)` | 시간 가중 평균 |
| `getWeeklyReport.maxFocusValue` (오늘 추가) | 시간 가중 평균 | 시간 가중 평균 |

5분 0.9 + 60분 0.5 → 단순평균 0.7, 가중평균 ≈ 0.53. **같은 "평균 집중도" 라벨이 화면마다 17% 가량 다른 값**을 보여줄 수 있음.

**수정**: 모든 평균을 시간 가중으로 통일 (`statsProvider`, `dailyReportProvider` 의 SQL 을 raw fetch + Dart 가중평균으로 교체).

---

### M2. `duration_minutes` floor 처리로 1분 미만 세션 = 0분
`study_session_provider.endSession`:
```dart
final durationMinutes = now.difference(session.startedAt).inMinutes;
```
`Duration.inMinutes` 는 floor. 사용자가 즉시 일시정지 누른 30초 세션은 `durationMinutes = 0`. `focus_score` 와 `ended_at` 는 채워진 채 0분짜리 row 로 DB 저장됨.

영향:
- 차트의 시간 합계는 정확 (0+나머지)
- 하지만 `getDailyReport` 의 평균은 SQL `AVG(focus_score)` 라 0분 row 도 포함 → 통계 노이즈
- Activity 타임라인에 "duration 0분" 으로 표시될 수 있음

**수정**: `inSeconds < 30` 인 세션은 저장 자체를 스킵하거나, `(inSeconds / 60).ceil()` 로 라운딩.

---

### M3. 미완료 세션(orphaned) 누적 가능
`startSession` 이 row 를 insert 하고, `endSession` 이 update. 사용자가 세션 중 앱 강제 종료 / 디바이스 재부팅 시 **`ended_at = NULL` row 가 영구 잔존**. 다음에 다른 세션 시작해도 청소 안 됨.

영향:
- 모든 통계 쿼리가 `WHERE ended_at IS NOT NULL` 필터하므로 차트 자체는 영향 없음 ✓
- 하지만 누적되면서 DB 가 부풀어 오름
- 시연 도중 한번이라도 강제 종료가 있었으면, 그 세션 시각 기준 차트 검증이 안 됨

**수정**: 앱 시작 시 `DELETE FROM study_sessions WHERE ended_at IS NULL AND started_at < ? (24시간 전)` 로 청소.

---

### M4. `_onUpgrade` 가 transaction 으로 감싸지지 않음
`_onCreate` 는 `db.transaction()` 안에서 실행. `_onUpgrade` 는 일반 execute 연속:
```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) { await db.execute('...'); }
  if (oldVersion < 3) { await db.execute('...'); await db.execute('...'); }
  if (oldVersion < 4) { await db.execute('...'); await db.execute('...'); }
}
```
중간 ALTER 가 실패하면 DB 가 어중간한 상태로 남고 다음 부팅에 더 큰 문제 발생.

**수정**: `await db.transaction((txn) async { ... })` 로 감싸기.

---

### M5. FSRS-5 reference 와 수치 비교 안 됨 — 수식 부정확 의심
4주차 산출물 "FSRS v5 레퍼런스 구현과 수치 비교" 가 미검증 상태.

`fsrs_engine._nextStability` 의 본 수식:
```dart
return s *
    (_w[8] *
            math.exp(_w[9] * (1 - r)) *
            (math.pow(d, -_w[10]) * math.pow(s + 1, _w[15]) - 1) *
            bonus +
        1);
```
- `_w[15]` 가 `(s+1)^_w[15]` 의 지수와 hard-rating 패널티 스칼라 두 곳에서 사용됨. 일반적인 FSRS-5 레퍼런스는 `S^(-w9)` 패턴이라 이 식이 reference 와 다름.

`_nextInterval`:
```dart
final interval = stability * math.log(0.9) / math.log(1 + 19/81 * -0.5);
```
계산: `S × (-0.105) / (-0.124) ≈ S × 0.847`.
정답 공식: `S × (R^(-2) - 1) × 81/19 ≈ S × 0.998`.
즉 **목표 retention 0.9 를 위한 간격이 15% 짧게 계산됨** → 사용자에게 더 자주 복습.

**수정**: `py-fsrs` (공식 reference) 결과와 같은 입력으로 5케이스 비교 후 수식 보정. 단위 테스트 동시 작성.

---

### M6. 만료된 dueDate 자동 nullify 미구현
`CLAUDE.md` 명시:
> 만료된 마감 할일: dueDate 경과 시 dueDate = null로 초기화 → 자유 학습으로 전환

현재 코드: `priority_calculator` 가 `daysLeft >= 0` 만 부스트하므로 지난 시험은 *부스트만* 빠지고 dueDate 는 그대로 남음. 화면에 "D-3 (지남)" 같이 표시되거나, `daysUntilDeadline` 이 음수 반환되어 UI 가 깨질 수 있음.

**수정**: 앱 시작 시 또는 `getDueToday` 호출 시 `UPDATE study_goals SET due_date = NULL, mode = 'study' WHERE due_date < ?` 마이그레이션 잡 추가.

---

## 🟡 Minor 9건

### m1. focus score 스케일 (0~1 vs 0~100) 시그니처 표기 누락
- `study_sessions.focus_score` 컬럼: 0~1
- `FsrsRating.fromFocusScore` 입력: 0~100
- `endSession` 에서만 `* 100` 변환
- `applyFocusScore(StudyGoal, double focusScore)` 시그니처에 단위 명시 없음

향후 누군가 다른 위치에서 `applyFocusScore(goal, 0.65)` 호출하면 → `Again` 등급 잘못 부여. 현재는 호출처 1개라 OK.

**수정**: 시그니처를 `applyFocusScore(StudyGoal, double focusScorePercent)` 로 rename.

### m2. `todo_items.priority` 인덱스 없음
`today_plan_provider` 가 priority 로 정렬 (`b.priority.compareTo(a.priority)`). 현재는 in-memory 정렬이라 영향 작지만, todo 100개 넘어가면 미세 지연.

**수정**: `CREATE INDEX idx_todos_priority ON todo_items(priority)`.

### m3. `StudySessionNotifier.build()` 가 빈 리스트 반환
state 자체가 의미 없음 (메서드 컨테이너로만 사용). `Notifier` 또는 `Provider` 가 더 맞음.

### m4. `getDueToday` 의 cutoff 가 23:59:59
```dart
final endOfDay = DateTime(today, 23, 59, 59).millisecondsSinceEpoch;
```
`23:59:59.000 ~ 23:59:59.999` 사이 1초 구간이 누락됨 (실용적 영향 거의 없음).

**수정**: `next_due < tomorrowMidnight.ms` 로 변경.

### m5. `Repository.save()` 가 두 번 쿼리 (getById + update/insert)
`subject_repository_impl.save`, `study_goal_repository_impl.save` 모두 `getById` 후 분기. `INSERT OR REPLACE` 한 번이면 충분.

### m6. `_nextInterval.clamp(1, 365)` — 1일 최저
relearning 의 즉시 재복습 (5분~10분 단위) 표현 불가. 단순 디자인이면 OK.

### m7. WeeklyReport.maxFocusDay 동률 처리
가장 이른 날 우선 (Map insertion order). 보장은 되지만 명시 안 됨.

### m8. `openInMemory()` 정적 팩토리가 instance 의 private 메서드를 호출
```dart
static Future<Database> openInMemory() async {
  return openDatabase(
    inMemoryDatabasePath,
    onCreate: (db, _) => instance._onCreate(db, _dbVersion),
    ...
```
호출 자체는 동작하지만 의미상 어색. private 인스턴스 멤버를 정적에서 노출.

### m9. camera_page 의 `'20:38'` 텍스트 타이머 + `mockFocusScore = 0.65`
이미 알려진 TODO. 7주차 산출물 (동적 타이머) 완료 시 함께 해결.

---

## 새로 추가한 코드 자가 검토

오늘 추가한 `stats_provider.dart` 의 5개 함수와 단위 테스트 17개를 자가 검토:

| 검토 항목 | 결과 |
|---|---|
| 시간대 버킷 정렬 | 시작 시각 hour 기준 (정책 결정 #3 그대로) ✓ |
| 가중 평균 일관성 | `_BucketAgg.focusWeightedSum / focusWeightMinutes` 정확 ✓ |
| 빈 결과 처리 | 모든 함수 빈 DB 케이스 테스트됨 ✓ |
| 미완료 세션 제외 | `WHERE ended_at IS NOT NULL` 일관 적용 ✓ |
| `focusWeightMinutes > 0` null guard | 적용됨 ✓ |
| 타임존 의존성 | local hour 추출 (Dart `DateTime.fromMillisecondsSinceEpoch`) → 디바이스 tz 의존 (의도된 동작) |
| 다른 평균 정의와의 일관성 | **❌ M1 위반** (단순평균 vs 가중평균 혼재) |
| `completed_at` 의존 | M3 (markTaskDoneByText) / C2 (camera_page) 가 stamp 안 함 → 새 리포트 통계에 미반영 |

**즉 새 코드 자체는 거의 결함 없지만, 호출 측의 토글 경로 미수정으로 통계가 부분만 잡힘**.

---

## 권장 수정 순서

| 우선순위 | 작업 | 예상 분량 |
|---|---|---|
| P0 | C1 — `Color.value` 로 변경 (또는 SDK 하한 올림) | 5분 |
| P0 | C2 — camera_page._toggleDone 가 DB 호출 | 30분 |
| P0 | C3 — `_toDomain` / `markTaskDoneByText` 가 completedAt 처리 | 30분 |
| P0 | C4 — 삭제 시 관련 provider invalidate 추가 | 15분 |
| P1 | M1 — 평균 정의 통일 (시간 가중) | 1시간 + 테스트 갱신 |
| P1 | M2 — duration < 30초 세션 처리 | 15분 |
| P1 | M5 — FSRS-5 reference 비교 + 수식 보정 | 2~3시간 (단위 테스트 포함) |
| P2 | M3 — orphaned 세션 청소 | 30분 |
| P2 | M4 — `_onUpgrade` transaction 감싸기 | 10분 |
| P2 | M6 — 만료 dueDate 자동 nullify | 30분 |
| P3 | Minor 9건 | 합쳐서 2시간 |

---

*작성: 2026-04-26 / 검토자: 백엔드 (이유신)*
