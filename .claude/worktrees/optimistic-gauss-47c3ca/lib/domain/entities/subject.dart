import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String name;
  final Color color;

  const Subject({
    required this.id,
    required this.name,
    required this.color,
  });

  Subject copyWith({String? id, String? name, Color? color}) => Subject(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
      };

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
        id: map['id'] as String,
        name: map['name'] as String,
        color: Color(map['color'] as int),
      );
}
