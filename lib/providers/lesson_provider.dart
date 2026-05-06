import 'package:flutter/material.dart';
import '../models/lesson_model.dart';
import '../data/lessons_data.dart';

class LessonProvider extends ChangeNotifier {
  final List<LessonModel> _lessons = LessonsData.lessons;

  List<LessonModel> get lessons => _lessons;

  LessonModel? get featuredLesson =>
      _lessons.isNotEmpty ? _lessons.first : null;

  List<String> get topics => [
    "Human Anatomy",
    "Solar System",
    "Microbiology",
    "Engineering",
    "Architecture",
  ];
}
