// lib/models/reading_goal_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalPeriod { daily, weekly, monthly, yearly }
enum GoalType { books, pages }

class ReadingGoalModel {
  final String id;
  final String userId;
  final GoalPeriod period;
  final GoalType type;
  final int targetCount; // hedef kitap veya sayfa sayısı
  final int year; // hangi yıla ait
  final DateTime createdAt;
  final DateTime updatedAt;

  ReadingGoalModel({
    required this.id,
    required this.userId,
    required this.period,
    required this.type,
    required this.targetCount,
    required this.year,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'period': period.name,
      'type': type.name,
      'targetCount': targetCount,
      'year': year,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ReadingGoalModel.fromMap(Map<String, dynamic> map) {
    return ReadingGoalModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      period: GoalPeriod.values.firstWhere(
        (e) => e.name == map['period'],
        orElse: () => GoalPeriod.yearly,
      ),
      type: GoalType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => GoalType.books,
      ),
      targetCount: map['targetCount'] ?? 0,
      year: map['year'] ?? DateTime.now().year,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  ReadingGoalModel copyWith({
    String? id,
    String? userId,
    GoalPeriod? period,
    GoalType? type,
    int? targetCount,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReadingGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      period: period ?? this.period,
      type: type ?? this.type,
      targetCount: targetCount ?? this.targetCount,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
