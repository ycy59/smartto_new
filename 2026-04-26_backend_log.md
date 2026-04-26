# 2026-04-26 백엔드 작업 일지

> Smartto 캡스톤 / 백엔드 (이유신)
> 리포트 페이지 데이터 연동 — DB·Provider 단 완성

---

## 한 줄 요약

리포트 페이지(일간/주간 탭)가 더미 데이터를 떼고 실제 SQLite 집계로 동작할 수 있도록 **DB 스키마 v4 마이그레이션 + 집계 함수 5종 + 단위 테스트 17개**를 추가. 프론트는 더미 자리에 `ref.watch(...)` 한 줄만 갈아끼우면 됨.

---

## 1. 정책 결정 4건 (사용자 확정)

리포트 화면 더미 라벨이 "무엇을 세야 하는지" 모호한 것 4개를 확정:

| 항목 | 결정 |
|---|---|
| 일간 통계 카드 "완료 과목" | `todo_items.completed_at` 이 그날 안에 들어간 todo 개수 |
| 일간 도넛 "Full / Part Time" | `study_goals.mode = 'exam'` vs `'study'` 의 학습 시간 비율 |
| 시간대별 차트 분배 | 한 세션이 여러 시간대 걸치더라도 **시작 시각 hour 버킷에 통째로** |
| Activity 타임라인 단위 | `study_goals.title` 까지만 (스키마 변경 없이 즉시 가능) |

---

## 2. DB 마이그레이션 (v3 → v4)

`todo_items` 테이블에 완료 시각 컬럼 추가. "오늘 완료한 todo 수" 집계의 전제 조건.

```sql
ALTER TABLE todo_items ADD COLUMN completed_at INTEGER;
CREATE INDEX idx_todos_completed_at ON todo_items(completed_at);
```

기존 v3 사용자의 `is_done = 1` 데이터는 마이그레이션 시 `completed_at = NULL` 로 들어가며,
일자별 집계에서 자동으로 제외됨 (의도된 동작). 새로 토글되는 todo 부터 `TodoItem.toggleDone()` 헬퍼가 자동으로 stamp.

---

## 3. 코드 변경 — 6개 파일

| 파일 | 변경 |
|---|---|
| `lib/data/db/database_helper.dart` | `_dbVersion` 4 로 bump, `completed_at` 컬럼 + 인덱스, `_onUpgrade` v3→v4 분기, 테스트용 `openInMemory()` 팩토리 |
| `lib/domain/entities/todo_item.dart` | `completedAt: DateTime?` 필드 추가, `toggleDone(bool)` 헬퍼 (false→true: 현재시각 stamp / true→false: null 리셋) |
| `lib/providers/today_plan_provider.dart` | `toggleTodoDone` 가 `toggleDone()` 사용하도록 갱신 — UI 측 토글 동작은 그대로, completed_at 만 자동 따라감 |
| `lib/providers/stats_provider.dart` | 데이터 클래스 6개 + 정적 `ReportQueries` (5개 메서드) + `FutureProvider.family` 5개 추가. 기존 `statsProvider` (Greeting / Weekly 카드 의존) 는 그대로 유지 |
| `pubspec.yaml` | dev_dependencies 에 `sqflite_common_ffi: ^2.3.0` 추가 (단위 테스트가 host VM 에서 in-memory sqflite 띄우기 위함) |
| `test/providers/stats_provider_test.dart` | 신규. 17개 테스트 케이스, in-memory sqflite + fixture 헬퍼 |

---

## 4. 새 Provider API (UI 호출 가이드)

리포트 페이지 더미 데이터 자리에 그대로 갈아끼울 수 있도록 5개 family provider 노출.

```dart
// 일간 시간대별 × 과목 매트릭스 — _HourlyBarChart
ref.watch(dailyHourlyBucketsProvider(DateTime(2026, 4, 26)))
//  → AsyncValue<List<HourlyBucket>>
//    HourlyBucket: { hour, subjectId, subjectName, subjectColor, minutes, avgFocus(0~100) }

// 일간 통계 카드 3개
ref.watch(dailyReportProvider(DateTime(2026, 4, 26)))
//  → AsyncValue<DailyReport>
//    DailyReport: { totalMinutes, completedTodos, avgFocus(0~100) }

// 일간 도넛 — exam vs study 비율
ref.watch(dailyModeRatioProvider(DateTime(2026, 4, 26)))
//  → AsyncValue<ModeRatio>
//    ModeRatio: { examMinutes, studyMinutes, examRatio(0~1), studyRatio(0~1) }

// Activity 타임라인 (시작시각 ASC)
ref.watch(dailyActivitiesProvider(DateTime(2026, 4, 26)))
//  → AsyncValue<List<ActivityEntry>>
//    ActivityEntry: { sessionId, startedAt, durationMinutes, focusScore(0~1),
//                     goalTitle, subjectName, subjectColor }

// 주간 리포트 (월요일 자정 전달)
ref.watch(weeklyReportProvider(DateTime(2026, 4, 20)))
//  → AsyncValue<WeeklyReport>
//    WeeklyReport: { buckets[DaySubjectBucket], totalMinutes, completedTodos,
//                    maxFocusDay, maxFocusValue(0~100) }
```

---

## 5. 검증

Sandbox 에 Dart SDK 가 없어 `flutter analyze` / `dart test` 실 실행은 못함. 대신 grep 기반 정적 검증:

- `domain.TodoItem(...)` 호출처 5건 모두 named-arg 형식 → optional `completedAt` 추가가 기존 호출 깨뜨리지 않음 ✓
- `_BucketAgg` putIfAbsent 콜백에서 채워진 필드만 다운스트림 `!` 접근 → null-deref 없음 ✓
- 모든 import 사용처 존재 ✓
- 단위 테스트 17개 fixture·assertion 검증 (시간 분배, 다른날 제외, focus null, 미완료 세션 제외, 가중 평균, 모드별 분리, 최고 집중일 등 엣지케이스 포함)

**팀원 측 실 검증 명령**:

```bash
cd ~/Desktop/대학/smartto_new
flutter pub get
flutter analyze
flutter test test/providers/stats_provider_test.dart
```

---

## 6. 이번주 남은 백엔드 작업 (P0 부터)

| P | 작업 | 비고 |
|---|---|---|
| **P0** | 동적 타이머 추천 함수 + 단위 테스트 | 7주차 산출물 회수. 발표 슬라이드 7 알고리즘 (`휴식 = 집중시간 / 5`, 최소 10분, 최대 사용자 설정) 그대로 구현 |
| **P0** | 카메라 페이지 실제 `Timer.periodic` | `'20:38'` 텍스트 자리 채우기. P0 동적 타이머 함수 호출해서 휴식 추천 모달 띄우기 |
| **P1** | FSRS 단위 테스트 | 4주차 산출물 회수. `fsrs_engine.dart` 의 `initFromLevel` / `review` / `currentRetrievability` 검증 |
| **P2** | 캘린더 페이지 데이터 연동 | `getByDateRange()` 이미 있음. ConsumerWidget 전환 + 날짜별 세션 표시 |

---

## 7. 알려진 한계 / 다음 결정 사항

- **시간대 차트가 시작시각 단일 버킷이라**, 1시간을 넘는 세션의 분할은 시각적으로 부정확. 발표 시연에는 충분하지만, 정밀 통계가 필요할 때는 분 단위 분배로 업그레이드 가능 (Dart 측 분할 로직 추가만 필요).
- **Activity 타임라인이 goal 단위**라 화면 더미의 *"1. sqld 정의, 개념"* 같은 todo 단위 상세는 표시 못함. 필요해지면 `study_sessions` 에 `todo_id` 컬럼 v5 마이그레이션 + `camera_page._startSession()` 시그니처 수정 (∼1시간 작업).
- **completed_at 가 v4 신규 컬럼**이라 v3 시절 이미 done 으로 토글된 todo 는 일자 집계에 잡히지 않음. 시연 직전 더미 todo 를 새로 토글하면 즉시 차트에 반영됨.

---

*작성: 이유신 / 2026-04-26*
