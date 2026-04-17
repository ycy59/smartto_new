import 'package:smartto_new/domain/entities/study_goal.dart';

class TodoItem {
  final String id;
  final String goalId;
  final String text;
  final bool isDone;
  final int position;
  final int priority; // 0 = 보통, 1 = 중요, 2 = 매우 중요
  final StudyMode mode; // 학습/시험 모드 (할 일별)
  final DateTime? dueDate; // 시험일자 (시험 모드일 때만)

  const TodoItem({
    required this.id,
    required this.goalId,
    required this.text,
    required this.isDone,
    required this.position,
    this.priority = 0,
    this.mode = StudyMode.study,
    this.dueDate,
  });

  TodoItem copyWith({
    String? id,
    String? goalId,
    String? text,
    bool? isDone,
    int? position,
    int? priority,
    StudyMode? mode,
    DateTime? Function()? dueDate,
  }) =>
      TodoItem(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        text: text ?? this.text,
        isDone: isDone ?? this.isDone,
        position: position ?? this.position,
        priority: priority ?? this.priority,
        mode: mode ?? this.mode,
        dueDate: dueDate != null ? dueDate() : this.dueDate,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'text': text,
        'is_done': isDone ? 1 : 0,
        'position': position,
        'priority': priority,
        'mode': mode == StudyMode.exam ? 'exam' : 'study',
        'due_date': dueDate?.millisecondsSinceEpoch,
      };

  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(
        id: map['id'] as String,
        goalId: map['goal_id'] as String,
        text: map['text'] as String,
        isDone: (map['is_done'] as int) == 1,
        position: map['position'] as int,
        priority: (map['priority'] as int?) ?? 0,
        mode: (map['mode'] as String?) == 'exam'
            ? StudyMode.exam
            : StudyMode.study,
        dueDate: map['due_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
            : null,
      );
}
