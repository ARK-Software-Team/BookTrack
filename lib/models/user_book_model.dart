// lib/models/user_book_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'book_model.dart';

class UserBookModel {
  final String id; // Firestore document ID (userBooks/{id})
  final String userId;
  final BookModel book;
  final ReadingStatus status;
  final double? rating; // 1.0 - 5.0
  final String? review;
  final int currentPage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime addedAt;
  final DateTime updatedAt;
  final List<ReadingSession> readingSessions;

  UserBookModel({
    required this.id,
    required this.userId,
    required this.book,
    required this.status,
    this.rating,
    this.review,
    this.currentPage = 0,
    this.startedAt,
    this.finishedAt,
    required this.addedAt,
    required this.updatedAt,
    this.readingSessions = const [],
  });

  /// Toplam okunan sayfa sayısı (tüm session'lardan)
  int get totalPagesRead {
    if (status == ReadingStatus.read && book.pageCount != null) {
      return book.pageCount!;
    }
    return currentPage;
  }

  /// Okuma yüzdesi
  double get progressPercent {
    if (book.pageCount == null || book.pageCount == 0) return 0;
    return (currentPage / book.pageCount!).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'book': book.toMap(),
      'status': status.name,
      'rating': rating,
      'review': review,
      'currentPage': currentPage,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt':
          finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'readingSessions': readingSessions.map((s) => s.toMap()).toList(),
    };
  }

  factory UserBookModel.fromMap(Map<String, dynamic> map) {
    return UserBookModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      book: BookModel.fromMap(map['book'] as Map<String, dynamic>),
      status: ReadingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReadingStatus.wantToRead,
      ),
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'],
      currentPage: map['currentPage'] ?? 0,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      finishedAt: (map['finishedAt'] as Timestamp?)?.toDate(),
      addedAt: (map['addedAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      readingSessions: (map['readingSessions'] as List<dynamic>?)
              ?.map((s) => ReadingSession.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  UserBookModel copyWith({
    String? id,
    String? userId,
    BookModel? book,
    ReadingStatus? status,
    double? rating,
    String? review,
    int? currentPage,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? addedAt,
    DateTime? updatedAt,
    List<ReadingSession>? readingSessions,
  }) {
    return UserBookModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      book: book ?? this.book,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      currentPage: currentPage ?? this.currentPage,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readingSessions: readingSessions ?? this.readingSessions,
    );
  }
}

/// Tek bir okuma seansı (örneğin: 14:00-15:30, 40 sayfa)
class ReadingSession {
  final DateTime date;
  final int pagesRead;
  final int? durationMinutes;

  ReadingSession({
    required this.date,
    required this.pagesRead,
    this.durationMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'pagesRead': pagesRead,
      'durationMinutes': durationMinutes,
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    return ReadingSession(
      date: (map['date'] as Timestamp).toDate(),
      pagesRead: map['pagesRead'] ?? 0,
      durationMinutes: map['durationMinutes'],
    );
  }
}
