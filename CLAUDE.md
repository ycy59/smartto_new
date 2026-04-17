# SMARTTO — 프로젝트 컨텍스트

캡스톤 디자인 프로젝트. MediaPipe 집중도 측정 + FSRS-5 간격반복 알고리즘을 결합한 스마트 뽀모도로 앱.

## 앱 핵심 로직

```
과목 추가 (SubjectPage)
  → FSRS 초기화 (이해도 기반 stability 설정, nextDue = 오늘)
  → 오늘의 계획 우선순위 정렬 (홈 화면)
  → 집중 세션 시작 (CameraPage, MediaPipe 측정)
  → 세션 종료 → 집중도 점수 → FsrsRating 변환
  → FSRS 파라미터 업데이트 (stability / difficulty / retrievability)
  → 다음 복습일 자동 계산 (nextDue 갱신)
```

**집중도 → FsrsRating 매핑**
- 0~40% → Again (재학습), 40~60% → Hard, 60~80% → Good, 80~100% → Easy

**우선순위 계산**
- `score = overdue_days + deadline_bonus`
- `deadline_bonus`: 시험 모드 + 마감 7일 이내일 때 (7 - 남은일수) 가중치

---

## 완료된 작업

### 백엔드 구조 (lib/)

```
lib/
├── algorithms/
│   ├── fsrs/
│   │   ├── fsrs_state.dart       StudyGoalState / FsrsRating / FsrsConstants
│   │   └── fsrs_engine.dart      FSRS-5 계산 엔진
│   └── priority_calculator.dart  우선순위 정렬 로직
│
├── domain/
│   ├── entities/
│   │   ├── subject.dart          과목 (id, name, color)
│   │   ├── study_goal.dart       할일 + FSRS 파라미터
│   │   ├── todo_item.dart        세부 체크리스트
│   │   └── study_session.dart    공부 세션 (focus_score 포함)
│   └── repositories/             인터페이스 4개
│
├── data/
│   ├── db/database_helper.dart   SQLite 싱글턴
│   └── repositories/             구현체 4개
│
└── providers/
    ├── database_provider.dart    DI (DB / Repository)
    ├── subject_provider.dart     과목 CRUD
    ├── study_goal_provider.dart  할일 CRUD + FSRS 업데이트
    ├── study_session_provider.dart 세션 시작/종료
    ├── today_plan_provider.dart  오늘의 계획 (우선순위 정렬 + Subject 색상 join)
    └── stats_provider.dart       학습 통계 (오늘/이번주)
```

### SQLite 스키마

```sql
subjects       (id, name, color)
study_goals    (id, subject_id→FK, title, mode, understanding_level,
                due_date, stability, difficulty, retrievability,
                repetitions, state, last_review, next_due, created_at)
todo_items     (id, goal_id→FK, text, is_done, position)
study_sessions (id, goal_id→FK, started_at, ended_at,
                focus_score, duration_minutes, created_at)
```
- 모든 FK에 ON DELETE CASCADE 적용

### UI 연동

| 화면 | 연동 내용 |
|------|----------|
| main.dart | SharedPreferences로 온보딩 건너뛰기 (nickname, study_time_goal 저장) |
| subject_page.dart | ConsumerStatefulWidget, 과목 CRUD → DB 저장/수정/삭제 |
| main_screen.dart | TodayPlanCard → todayPlanProvider (실시간 반응), 편집 버튼 → SubjectPage 이동 |
| main_screen.dart | GreetingCard → 오늘 학습시간 / 목표시간 실제 데이터 |
| main_screen.dart | WeeklyStatsCard → 이번주 총집중 / 완료세션 / 평균집중도 실제 데이터 |
| camera_page.dart | CameraTask 타입, 세션 시작/종료 → FSRS 자동 업데이트 |

### 해결된 버그

1. **데이터 사라짐**: FSRS `initFromLevel`의 `nextDue`를 오늘 자정으로 수정
   - 기존: `now + stability_days` → getDueToday() 조회 불가
   - 수정: `DateTime(now.year, now.month, now.day)` → 즉시 오늘 계획에 노출
2. **앱 재시작 시 이름 재입력**: SharedPreferences로 온보딩 완료 상태 저장
3. **TodayPlanCard 갱신 안 됨**: `ref.listen(todayPlanProvider)` + `ref.invalidate` 적용

---

## 남은 작업 (우선순위 순)

### 1. MediaPipe 집중도 실제 연동 [HIGH]

**파일**: `lib/screens/camera_page.dart`

```dart
// 현재 (모의값)
const mockFocusScore = 0.65;

// 교체 필요: MediaPipe Face Mesh / Attention 점수를 실시간으로 받아서
// _endSession() 호출 시 실제 focusScore 전달
```

- MediaPipe Flutter 패키지 연동 필요
- 카메라 프리뷰 위젯과 점수 계산 로직 구현
- 집중도 점수 0.0~1.0 실시간 업데이트

### 2. 리포트 페이지 실제 데이터 연동 [HIGH]

**파일**: `lib/screens/report_page.dart`

- 현재 하드코딩된 차트 데이터 → `statsProvider` / DB 쿼리로 교체
- 일별 학습 시간 차트 (7일)
- 과목별 학습 비중 파이 차트
- 집중도 추이 그래프
- `study_sessions` 테이블에서 집계 쿼리 작성 필요

### 3. 캘린더 페이지 실제 데이터 연동 [MEDIUM]

**파일**: `lib/screens/calendar_page.dart`

- 날짜별 학습 세션 표시
- 각 날짜의 `study_sessions` 데이터 로드
- D-day 표시 (study_goals.due_date 기반)
- `getByDateRange(from, to)` 이미 repository에 구현되어 있음

### 4. MyPage 프로필 편집 연동 [MEDIUM]

**파일**: `lib/screens/my_page.dart`

- 닉네임 수정 → SharedPreferences('nickname') 업데이트
- 목표 시간 수정 → SharedPreferences('study_time_goal') 업데이트
- 프로필 이미지 → SharedPreferences에 경로 저장
- 현재 `onProfileUpdated` 콜백은 있지만 DB/Prefs 저장 안 됨

### 5. 세션 타이머 실제 구현 [MEDIUM]

**파일**: `lib/screens/camera_page.dart`

- 현재 타이머 '20:38' 하드코딩
- `startedAt` 기준으로 실제 경과 시간 표시
- 뽀모도로 모드: 25분 집중 / 5분 휴식 사이클

### 6. 과목 추가 후 홈 즉시 반영 검증 [LOW]

- SubjectPage에서 과목 추가 → HomeScreen으로 돌아올 때 TodayPlanCard 자동 갱신 확인
- `ref.listen(todayPlanProvider)` + `_loadTodayPlan()` 타이밍 검증

### 7. 온보딩 목표 시간 변경 기능 [LOW]

- MyPage에서 목표 시간 변경 시 `statsProvider` 즉시 갱신
- `ref.read(statsProvider.notifier).refresh()` 호출

---

## 주요 파일 위치

| 역할 | 파일 |
|------|------|
| FSRS 등급 매핑 | `lib/algorithms/fsrs/fsrs_state.dart` - `FsrsRating.fromFocusScore()` |
| FSRS 계산 | `lib/algorithms/fsrs/fsrs_engine.dart` - `review()` |
| 우선순위 계산 | `lib/algorithms/priority_calculator.dart` |
| DB 스키마 | `lib/data/db/database_helper.dart` |
| 세션 종료 흐름 | `lib/providers/study_session_provider.dart` - `endSession()` |
| 통계 쿼리 | `lib/providers/stats_provider.dart` |
| MediaPipe 연동 위치 | `lib/screens/camera_page.dart` - `_endSession()` 내 `mockFocusScore` |

---

## 개발 규칙

- 상태관리: **Riverpod** (flutter_riverpod 2.x)
- 로컬 DB: **sqflite** (SQLite)
- 온보딩 상태: **SharedPreferences** (nickname, study_time_goal, onboarding_complete)
- ID 생성: **uuid** v4
- 이상한 부분은 구현 전 반드시 토의 후 진행
- UI 변경 없이 백엔드만 수정할 때는 `flutter analyze` 후 커밋
