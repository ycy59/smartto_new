import 'package:smartto_new/algorithms/fsrs/fsrs_state.dart';
import 'todo_item.dart';

enum StudyMode { study, exam }

enum UnderstandingLevel { hard, normal, easy }

extension UnderstandingLevelX on UnderstandingLevel {
  String toDbString() => switch (this) {
        UnderstandingLevel.hard => 'hard',
        UnderstandingLevel.normal => 'normal',
        UnderstandingLevel.easy => 'easy',
      };

  static UnderstandingLevel fromDbString(String s) => switch (s) {
        'hard' => UnderstandingLevel.hard,
        'normal' => UnderstandingLevel.normal,
        'easy' => UnderstandingLevel.easy,
        _ => UnderstandingLevel.normal,
      };
}

class StudyGoal {
  final String id;
  final String subjectId;
  final String title;
  final StudyMode mode;
  final UnderstandingLevel understandingLevel;
  final DateTime? dueDate;

  // FSRS 파라미터
  final double stability;
  final double difficulty;
  final double retrievability;
  final int repetitions;
  final StudyGoalState state;
  final DateTime? lastReview;
  final DateTime nextDue;
  final DateTime createdAt;

  // 세부 체크리스트 (DB join 시 채워짐)
  final List<TodoItem> todos;

  bool get isDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDue.year, nextDue.month, nextDue.day);
    return !due.isAfter(today);
  }

  int? get daysUntilDeadline {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return target.difference(today).inDays;
  }

  const StudyGoal({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.mode,
    required this.understandingLevel,
    this.dueDate,
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.repetitions,
    required this.state,
    this.lastReview,
    required this.nextDue,
    required this.createdAt,
    this.todos = const [],
  });

  StudyGoal copyWith({
    String? id,
    String? subjectId,
    String? title,
    StudyMode? mode,
    UnderstandingLevel? understandingLevel,
    DateTime? Function()? dueDate,
    double? stability,
    double? difficulty,
    double? retrievability,
    int? repetitions,
    StudyGoalState? state,
    DateTime? Function()? lastReview,
    DateTime? nextDue,
    DateTime? createdAt,
    List<TodoItem>? todos,
  }) =>
      StudyGoal(
        id: id ?? this.id,
        subjectId: subjectId ?? this.subjectId,
        title: title ?? this.title,
        mode: mode ?? this.mode,
        understandingLevel: understandingLevel ?? this.understandingLevel,
        dueDate: dueDate != null ? dueDate() : this.dueDate,
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        retrievability: retrievability ?? this.retrievability,
        repetitions: repetitions ?? this.repetitions,
        state: state ?? this.state,
        lastReview: lastReview != null ? lastReview() : this.lastReview,
        nextDue: nextDue ?? this.nextDue,
        createdAt: createdAt ?? this.createdAt,
        todos: todos ?? this.todos,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'mode': mode == StudyMode.exam ? 'exam' : 'study',
        'understanding_level': understandingLevel.toDbString(),
        'due_date': dueDate?.millisecondsSinceEpoch,
        'stability': stability,
        'difficulty': difficulty,
        'retrievability': retrievability,
        'repetitions': repetitions,
        'state': state.toDbString(),
        'last_review': lastReview?.millisecondsSinceEpoch,
        'next_due': nextDue.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory StudyGoal.fromMap(Map<String, dynamic> map,
      {List<TodoItem> todos = const []}) =>
      StudyGoal(
        id: map['id'] as String,
        subjectId: map['subject_id'] as String,
        title: map['title'] as String,
        mode: map['mode'] == 'exam' ? StudyMode.exam : StudyMode.study,
        understandingLevel: UnderstandingLevelX.fromDbString(
            map['understanding_level'] as String),
        dueDate: map['due_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
            : null,
        stability: (map['stability'] as num).toDouble(),
        difficulty: (map['difficulty'] as num).toDouble(),
        retrievability: (map['retrievability'] as num).toDouble(),
        repetitions: map['repetitions'] as int,
        state: StudyGoalStateX.fromDbString(map['state'] as String),
        lastReview: map['last_review'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_review'] as int)
            : null,
        nextDue:
            DateTime.fromMillisecondsSinceEpoch(map['next_due'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        todos: todos,
      );
}
