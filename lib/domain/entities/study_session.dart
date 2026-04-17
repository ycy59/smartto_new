class StudySession {
  final String id;
  final String goalId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? focusScore; // 0.0 ~ 1.0 (MediaPipe 집중도)
  final int? durationMinutes;
  final DateTime createdAt;

  const StudySession({
    required this.id,
    required this.goalId,
    required this.startedAt,
    this.endedAt,
    this.focusScore,
    this.durationMinutes,
    required this.createdAt,
  });

  StudySession copyWith({
    String? id,
    String? goalId,
    DateTime? startedAt,
    DateTime? Function()? endedAt,
    double? Function()? focusScore,
    int? Function()? durationMinutes,
    DateTime? createdAt,
  }) =>
      StudySession(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt != null ? endedAt() : this.endedAt,
        focusScore: focusScore != null ? focusScore() : this.focusScore,
        durationMinutes:
            durationMinutes != null ? durationMinutes() : this.durationMinutes,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'focus_score': focusScore,
        'duration_minutes': durationMinutes,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory StudySession.fromMap(Map<String, dynamic> map) => StudySession(
        id: map['id'] as String,
        goalId: map['goal_id'] as String,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int)
            : null,
        focusScore:
            map['focus_score'] != null ? (map['focus_score'] as num).toDouble() : null,
        durationMinutes: map['duration_minutes'] as int?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
