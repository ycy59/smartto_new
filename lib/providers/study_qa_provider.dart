import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyQaEntry {
  final String subjectName;
  final int subjectColorValue; // Color.value (int)
  final String question;
  final String answer;
  final DateTime date;

  const StudyQaEntry({
    required this.subjectName,
    required this.subjectColorValue,
    required this.question,
    required this.answer,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'subjectName': subjectName,
        'subjectColorValue': subjectColorValue,
        'question': question,
        'answer': answer,
        'date': date.toIso8601String(),
      };

  factory StudyQaEntry.fromJson(Map<String, dynamic> json) => StudyQaEntry(
        subjectName: json['subjectName'] as String,
        subjectColorValue: json['subjectColorValue'] as int,
        question: json['question'] as String,
        answer: json['answer'] as String,
        date: DateTime.parse(json['date'] as String),
      );
}

class StudyQaNotifier extends StateNotifier<List<StudyQaEntry>> {
  StudyQaNotifier() : super([]) {
    _load();
  }

  static const _key = 'study_qa_entries';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => StudyQaEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> add(StudyQaEntry entry) async {
    state = [entry, ...state]; // 최신순
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }
}

final studyQaProvider =
    StateNotifierProvider<StudyQaNotifier, List<StudyQaEntry>>(
  (ref) => StudyQaNotifier(),
);
