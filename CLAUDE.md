# SMARTTO — 프로젝트 컨텍스트

캡스톤 디자인 프로젝트. ML Kit Face Detection + ONNX(xgb) 기반 집중도 측정과 FSRS-5 간격반복 알고리즘을 결합한 스마트 뽀모도로 앱.

## 앱 핵심 로직

```
과목 추가 (SubjectPage)
  → FSRS 초기화 (이해도 기반 stability, nextDue = 오늘 자정)
  → 오늘의 계획 우선순위 정렬 (홈 화면)
  → 집중 세션 시작 (CameraPage, ConcentrationService 측정)
  → 세션 종료 → 평균 집중도(0~1) → *100 → FsrsRating 변환
  → FSRS 파라미터 업데이트 (stability / difficulty / retrievability)
  → 다음 복습일 자동 계산 (nextDue 갱신)
```

**집중도 → FsrsRating 매핑** (`FsrsRating.fromFocusScore`, 0~100 스케일 입력)
- 0~40 → Again (재학습), 40~60 → Hard, 60~80 → Good, 80~100 → Easy

**focusScore 단위 규약 (혼동 주의)**
- `ConcentrationService.averageScore01` : 0.0 ~ 1.0
- `StudySessionNotifier.endSession(focusScore:)` : 0.0 ~ 1.0 입력
- 내부에서 *100 → `GoalsBySubjectNotifier.applyFocusScore(goal, focusPercent)` : 0 ~ 100
- `FsrsEngine.review(focusScore:)` 및 `FsrsRating.fromFocusScore` : 0 ~ 100

**우선순위 계산** (`PriorityCalculator`)
- `score = overdue_days + deadline_bonus`
- `deadline_bonus`: 시험 모드 + 마감 7일 이내일 때 (7 - 남은일수) 가중치

---

## 백엔드 구조 (lib/)

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
│   │   ├── todo_item.dart        세부 체크리스트 (+ priority/mode/dueDate/completedAt)
│   │   └── study_session.dart    공부 세션 (focus_score 포함)
│   └── repositories/             인터페이스 4개
│
├── data/
│   ├── db/database_helper.dart   SQLite 싱글턴 (현재 v4)
│   └── repositories/             구현체 4개
│
├── widgets/
│   └── concentration_service.dart  ML Kit Face Detection + ONNX(xgb) 추론 서비스
│
├── providers/
│   ├── database_provider.dart      DI (DB / Repository)
│   ├── subject_provider.dart       과목 CRUD
│   ├── study_goal_provider.dart    할일 CRUD + FSRS 업데이트(applyFocusScore)
│   ├── study_session_provider.dart 세션 시작/종료
│   ├── today_plan_provider.dart    오늘의 계획 (우선순위 정렬 + Subject 색상 join)
│   ├── stats_provider.dart         학습 통계 (오늘/이번주) + ReportQueries 집계
│   └── calendar_provider.dart      월 단위 집중도/복습 매트릭스 (캘린더용)
│
└── screens/
    ├── main_screen.dart
    ├── home_shell.dart
    ├── subject_page.dart
    ├── camera_page.dart
    ├── report_page.dart
    ├── calendar_page.dart
    └── my_page.dart
```

## SQLite 스키마 (v4)

```sql
subjects       (id, name, color)
study_goals    (id, subject_id→FK, title, mode, understanding_level,
                due_date, stability, difficulty, retrievability,
                repetitions, state, last_review, next_due, created_at)
todo_items     (id, goal_id→FK, text, is_done, position,
                priority, mode, due_date, completed_at)
study_sessions (id, goal_id→FK, started_at, ended_at,
                focus_score, duration_minutes, created_at)
```
- 모든 FK에 ON DELETE CASCADE 적용
- `_onCreate`는 트랜잭션 안에서 실행. `_onUpgrade`는 v2(priority) → v3(mode/due_date) → v4(completed_at) 단계별 ALTER

## ConcentrationService 구조 (요약)

`lib/widgets/concentration_service.dart` (832줄). 카메라 프레임 → ML Kit face contour + head pose + eyeOpenProbability → 10차원 프레임 벡터 → 30초 윈도우 → 62차원 통계 → ONNX(`assets/models/xgb_model.onnx`) 추론 → 집중(1)/비집중(0) + probability → 50/30/20 점수(ML 50% + presence 30% + stare 20%) → `averageScore01`(0~1) 누적.

- 사용자별 EAR/MAR baseline calibration 동작
- 졸음(EAR long-close), 하품(MAR baseline ×1.5) 룰 포함
- iris 미지원 → gaze는 학습 분포 평균 0으로 강제
- `recommendNextSession`으로 다음 세션 길이 추천 노출

---

## UI 연동 현황

| 화면 | 연동 내용 |
|------|----------|
| main.dart | SharedPreferences로 온보딩 건너뛰기 (nickname, study_time_goal, onboarding_complete) |
| subject_page.dart | ConsumerStatefulWidget, 과목 CRUD → DB 저장/수정/삭제 |
| main_screen.dart | TodayPlanCard → todayPlanProvider, 편집 버튼 → SubjectPage 이동 |
| main_screen.dart | GreetingCard → 오늘 학습시간 / 목표시간 실제 데이터 |
| main_screen.dart | WeeklyStatsCard → 이번주 총집중 / 완료세션 / 평균집중도 실제 데이터 |
| camera_page.dart | CameraTask 타입, 실제 카운트다운 타이머(debug 1/1분, release 25/5분), ConcentrationService averageScore01 → endSession → FSRS 자동 업데이트 |
| report_page.dart | dailyReportProvider / dailyHourlyBucketsProvider / dailyModeRatioProvider / dailyActivitiesProvider / weeklyReportProvider 5종 watch (ReportQueries에서 SQL join) |
| calendar_page.dart | calendarMonthDataProvider — 일별 집중도(토마토 단계) + 복습 예정(goal next_due) 매트릭스 |
| my_page.dart | 닉네임 / 프로필 이미지 → SharedPreferences 저장 (저장하기 버튼) |

## 해결된 버그

1. **데이터 사라짐**: FSRS `initFromLevel`의 `nextDue`를 오늘 자정으로 수정 → 즉시 오늘 계획 노출
2. **앱 재시작 시 이름 재입력**: SharedPreferences로 온보딩 완료 상태 저장
3. **TodayPlanCard 갱신 안 됨**: `ref.listen(todayPlanProvider)` + `ref.invalidate` 적용
4. **세션 종료 후 캘린더 미반영**: `endSession`에서 `calendarMonthDataProvider` invalidate 추가

---

## 남은 작업 (우선순위 순, 2026-05-08 기준)

### 1. FSRS 단위 일관성 + 단위 테스트 [HIGH]

**파일**: `lib/providers/study_session_provider.dart`, `lib/providers/study_goal_provider.dart`, `lib/algorithms/fsrs/fsrs_state.dart`, 신규 `test/algorithms/fsrs_engine_test.dart`

- 호출 체인 자체는 맞지만(0~1 → *100 → 0~100) 각 함수 시그니처/주석에 단위가 명시 안 돼서 다음 사람이 잘못 호출하기 쉬움 → 주석 정비 (이미 진행)
- FSRS 엔진/PriorityCalculator는 캡스톤 핵심 알고리즘인데 테스트 0 → 4개 등급 경계(0.39/0.59/0.79), `_nextStability`/`_nextInterval` clamp, `initFromLevel` nextDue, overdue+deadline_bonus 정렬 회귀 테스트 필요
- 발표 시 "검증된 알고리즘"이라 말할 근거

### 2. MyPage 학습 목표 시간 편집 + 저장하기 흐름 정상화 [HIGH]

**파일**: `lib/screens/my_page.dart`, `lib/providers/stats_provider.dart`

- 닉네임/프로필 이미지는 SharedPreferences에 저장되지만 "저장하기" 누르지 않으면 영속 안 됨 (UX 미스)
- `study_time_goal` 변경 UI 자체가 없어서 홈 진행률%가 평생 같은 값
- 1/2/4/5h+ 목표 선택 UI 추가 → `study_time_goal` prefs 갱신 → `statsProvider.refresh()` 호출 → 홈 progress 즉시 반영

### 3. DB 마이그레이션 트랜잭션 래핑 [MEDIUM]

**파일**: `lib/data/db/database_helper.dart`

- `_onUpgrade`가 ALTER 4번을 트랜잭션 없이 직렬 실행 → 중간 실패 시 스키마 깨짐
- `db.transaction` 안에서 ALTER 실행하도록 수정 (5분 작업, 발표 직전 기기 교체 리스크 대비)

### 4. ONNX 모델 로드 실패 상태 UI 노출 [MEDIUM]

**파일**: `lib/widgets/concentration_service.dart`, `lib/screens/camera_page.dart`

- 현재 ONNX 로드 실패 시 silently 0.65 fallback → "ML 동작 중"으로 착각
- `_service.modelReady` 상태를 외부에 노출
- 카메라 화면 상단 배지에 "ML 모델 로딩 실패" 명시적 경고

### 5. 우선순위 계산기 / 캘린더 / ConcentrationService 점수 산식 테스트 [LOW]

- 1번에 이어 시간 남으면 추가
- ConcentrationService는 ML/카메라 의존이라 점수 합산 로직만 unit test로 분리

### 6. YUV420 멀티-plane 카메라 호환성 [BACKLOG]

**파일**: `lib/widgets/concentration_service.dart`

- `InputImage.fromBytes`가 첫 plane만 사용 → Android NV21은 OK, YUV420 멀티-plane 디바이스에선 metadata mismatch 위험
- 발표 디바이스에서 동작 확인되면 미루기

### 7. 과목 추가 후 홈 즉시 반영 검증 [BACKLOG]

- 이미 `ref.invalidate` 들어가 있어 동작은 함. 회귀 테스트 차원에서만 확인

---

## 주요 파일 위치

| 역할 | 파일 |
|------|------|
| FSRS 등급 매핑 (0~100 입력) | `lib/algorithms/fsrs/fsrs_state.dart` - `FsrsRating.fromFocusScore()` |
| FSRS 계산 | `lib/algorithms/fsrs/fsrs_engine.dart` - `review()` |
| 우선순위 계산 | `lib/algorithms/priority_calculator.dart` |
| DB 스키마 | `lib/data/db/database_helper.dart` |
| 세션 종료 흐름 (단위 변환 0~1 → 0~100) | `lib/providers/study_session_provider.dart` - `endSession()` |
| FSRS 업데이트 진입점 (0~100 입력) | `lib/providers/study_goal_provider.dart` - `applyFocusScore()` |
| 통계 쿼리 | `lib/providers/stats_provider.dart` - `ReportQueries` |
| 캘린더 매트릭스 | `lib/providers/calendar_provider.dart` - `calendarMonthDataProvider` |
| ML Kit + ONNX 집중도 측정 | `lib/widgets/concentration_service.dart` |
| 측정값 fallback 위치 | `lib/screens/camera_page.dart` - `_endSession()` 내 `_serviceReady ? _service.averageScore01 : 0.65` |

---

## 개발 규칙

- 상태관리: **Riverpod** (flutter_riverpod 2.x)
- 로컬 DB: **sqflite** (SQLite, 현재 v4)
- ML/얼굴 인식: **google_mlkit_face_detection** + **onnxruntime** (`assets/models/xgb_model.onnx`)
- 카메라: **camera** (iOS BGRA8888 / Android NV21)
- 온보딩 상태: **SharedPreferences** (nickname, study_time_goal, onboarding_complete, profileImagePath)
- ID 생성: **uuid** v4
- 이상한 부분은 구현 전 반드시 토의 후 진행
- UI 변경 없이 백엔드만 수정할 때는 `flutter analyze` 후 커밋
- focusScore 단위는 함수마다 명시 (0~1 vs 0~100 혼동 금지)
