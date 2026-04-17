class TodoItem {
  final String id;
  final String goalId;
  final String text;
  final bool isDone;
  final int position;

  const TodoItem({
    required this.id,
    required this.goalId,
    required this.text,
    required this.isDone,
    required this.position,
  });

  TodoItem copyWith({
    String? id,
    String? goalId,
    String? text,
    bool? isDone,
    int? position,
  }) =>
      TodoItem(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        text: text ?? this.text,
        isDone: isDone ?? this.isDone,
        position: position ?? this.position,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal_id': goalId,
        'text': text,
        'is_done': isDone ? 1 : 0,
        'position': position,
      };

  factory TodoItem.fromMap(Map<String, dynamic> map) => TodoItem(
        id: map['id'] as String,
        goalId: map['goal_id'] as String,
        text: map['text'] as String,
        isDone: (map['is_done'] as int) == 1,
        position: map['position'] as int,
      );
}
