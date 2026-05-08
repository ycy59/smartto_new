enum StudyGoalState {
  newCard,
  learning,
  review,
  relearning,
}

extension StudyGoalStateX on StudyGoalState {
  String toDbString() => switch (this) {
        StudyGoalState.newCard => 'new',
        StudyGoalState.learning => 'learning',
        StudyGoalState.review => 'review',
        StudyGoalState.relearning => 'relearning',
      };

  static StudyGoalState fromDbString(String s) => switch (s) {
        'new' => StudyGoalState.newCard,
        'learning' => StudyGoalState.learning,
        'review' => StudyGoalState.review,
        'relearning' => StudyGoalState.relearning,
        _ => throw ArgumentError('Unknown StudyGoalState: $s'),
      };
}

enum FsrsRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  final int value;
  const FsrsRating(this.value);

  /// MediaPipe 집중도 점수(0~100) → FsrsRating 변환
  static FsrsRating fromFocusScore(double score) {
    if (score < 40) return FsrsRating.again;
    if (score < 60) return FsrsRating.hard;
    if (score < 80) return FsrsRating.good;
    return FsrsRating.easy;
  }
}

class FsrsConstants {
  static const List<double> initialStability = [2.1173, 3.1262, 4.2926, 5.5786];
  static const double forgettingCurveDecay = -0.5;
  static const double targetRetrievability = 0.9;
  static const List<double> weights = [
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0589,
    1.5330, 0.1544, 1.0040, 1.9395, 0.1100, 0.2900, 2.2700, 0.1500, 2.9898,
  ];

  /// 이해도 수준별 초기 stability
  /// hard → again 기준, normal → good 기준, easy → easy 기준
  static double initialStabilityForLevel(String level) => switch (level) {
        'hard' => initialStability[0],
        'normal' => initialStability[2],
        'easy' => initialStability[3],
        _ => initialStability[2],
      };
}
