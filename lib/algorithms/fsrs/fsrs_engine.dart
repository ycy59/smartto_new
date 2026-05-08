import 'dart:math' as math;
import 'fsrs_state.dart';

class FsrsResult {
  final double stability;
  final double difficulty;
  final double retrievability;
  final int repetitions;
  final StudyGoalState state;
  final DateTime lastReview;
  final DateTime nextDue;

  const FsrsResult({
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.repetitions,
    required this.state,
    required this.lastReview,
    required this.nextDue,
  });
}

class FsrsEngine {
  static const double _decay = FsrsConstants.forgettingCurveDecay;
  static const double _factor = 19 / 81;
  static const List<double> _w = FsrsConstants.weights;

  /// 신규 목표 생성 시 초기 FSRS 상태 설정
  /// nextDue = 오늘 → 즉시 오늘의 계획에 노출됨
  /// 첫 세션 종료 후 review()가 실제 FSRS 간격을 계산함
  static FsrsResult initFromLevel(String understandingLevel) {
    final s0 = FsrsConstants.initialStabilityForLevel(understandingLevel);
    final rating = switch (understandingLevel) {
      'hard' => FsrsRating.hard,
      'easy' => FsrsRating.easy,
      _ => FsrsRating.good,
    };
    final now = DateTime.now();
    return FsrsResult(
      stability: s0,
      difficulty: _initDifficulty(rating),
      retrievability: 1.0,
      repetitions: 0,
      state: StudyGoalState.newCard,
      lastReview: now,
      nextDue: DateTime(now.year, now.month, now.day), // 오늘 자정 → 즉시 due
    );
  }

  /// 집중도 점수 기반 복습 후 업데이트
  static FsrsResult review({
    required double stability,
    required double difficulty,
    required int repetitions,
    required DateTime? lastReview,
    required double focusScore,
  }) {
    final rating = FsrsRating.fromFocusScore(focusScore);
    final now = DateTime.now();
    final elapsed = _elapsedDays(lastReview ?? now, now);
    final r = _retrievability(elapsed, stability);

    final newDifficulty = _nextDifficulty(difficulty, rating);
    final newStability = _nextStability(stability, r, newDifficulty, rating);
    final nextInterval = _nextInterval(newStability);

    // 다음 복습일: 오늘 자정 + interval 일.
    // _nextInterval 이 최소 1 로 clamp 되므로 "내일부터" 가 자연스럽게 보장됨.
    // 같은 날 재복습은 의미가 없어 정책적으로 배제 — 사용자는 흐름을 바꿔
    // 다음 날 일찍 복습할 수 있음.
    // 예) 오늘 학습, interval=7  →  next_due = (오늘 자정) + 7일
    //     오늘 학습, interval=1  →  next_due = (오늘 자정) + 1일 = 내일 자정
    final today0 = DateTime(now.year, now.month, now.day);
    final nextDueAtMidnight = today0.add(Duration(days: nextInterval));

    return FsrsResult(
      stability: newStability,
      difficulty: newDifficulty,
      retrievability: r,
      repetitions: repetitions + 1,
      state: rating == FsrsRating.again
          ? StudyGoalState.relearning
          : StudyGoalState.review,
      lastReview: now,
      nextDue: nextDueAtMidnight,
    );
  }

  /// 현재 기억 잔존율 계산
  static double currentRetrievability({
    required DateTime? lastReview,
    required double stability,
  }) {
    if (lastReview == null) return 0.0;
    final elapsed = _elapsedDays(lastReview, DateTime.now());
    return _retrievability(elapsed, stability);
  }

  static double _retrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0.0;
    return math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();
  }

  static double _initDifficulty(FsrsRating r) {
    final d = _w[4] - math.exp(_w[5] * (r.value - 1)) + 1;
    return d.clamp(1.0, 10.0);
  }

  static double _nextDifficulty(double d, FsrsRating r) {
    // FSRS-5: delta_d = -w6 * (rating - 3), linear damping ((10 - d) / 9)
    // mean reversion 은 D0(Easy) 쪽으로 끌어당기도록 — 표준 식과 동일.
    // (기존 코드는 initialStability 를 잘못 가져다 쓰고 있었음)
    final delta = -_w[6] * (r.value - 3);
    final next = d + delta * ((10 - d) / 9);
    final d0Easy = _initDifficulty(FsrsRating.easy);
    return (_w[7] * d0Easy + (1 - _w[7]) * next).clamp(1.0, 10.0);
  }

  static double _nextStability(double s, double r, double d, FsrsRating rating) {
    // 실패(again) — FSRS-5 lapse 식
    //   S' = w11 * d^-w12 * ((s+1)^w13 - 1) * exp((1-r) * w14)
    if (rating == FsrsRating.again) {
      return _w[11] *
          math.pow(d, -_w[12]) *
          (math.pow(s + 1, _w[13]) - 1) *
          math.exp((1 - r) * _w[14]);
    }
    // 성공(hard/good/easy) — FSRS-5 SInc 식
    //   SInc = exp(w8) * (11 - d) * s^-w9 * (exp((1-r) * w10) - 1) * h * b
    //   S'   = s * (1 + SInc)
    // h = w15 (hard 일 때만), b = w16 (easy 일 때만), 둘 다 아니면 1.
    final hardPenalty = rating == FsrsRating.hard ? _w[15] : 1.0;
    final easyBonus = rating == FsrsRating.easy ? _w[16] : 1.0;
    return s *
        (1 +
            math.exp(_w[8]) *
                (11 - d) *
                math.pow(s, -_w[9]) *
                (math.exp((1 - r) * _w[10]) - 1) *
                hardPenalty *
                easyBonus);
  }

  static int _nextInterval(double stability) {
    // FSRS-5 표준: I(R, S) = (S / FACTOR) * (R^(1/DECAY) - 1)
    // 목표 retrievability 시점까지의 일수.
    // R=0.9, FACTOR=19/81, DECAY=-0.5 일 때 I ≈ S.
    final interval = (stability / _factor) *
        (math.pow(FsrsConstants.targetRetrievability, 1 / _decay) - 1);
    return interval.round().clamp(1, 365);
  }

  static double _elapsedDays(DateTime from, DateTime to) =>
      to.difference(from).inMinutes / 1440.0;
}
