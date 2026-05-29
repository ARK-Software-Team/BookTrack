// lib/models/book_model.dart

enum ReadingStatus { wantToRead, reading, read }

class BookModel {
  final String id; // Firestore document ID
  final String title;
  final String author;
  final String? isbn;
  final String? coverUrl;
  final int? pageCount;
  final String? publisher;
  final int? publishYear;
  final String? description;
  final bool isManuallyAdded;
  final String? openLibraryKey; // Open Library'den geldiyse

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    this.isbn,
    this.coverUrl,
    this.pageCount,
    this.publisher,
    this.publishYear,
    this.description,
    this.isManuallyAdded = false,
    this.openLibraryKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'coverUrl': coverUrl,
      'pageCount': pageCount,
      'publisher': publisher,
      'publishYear': publishYear,
      'description': description,
      'isManuallyAdded': isManuallyAdded,
      'openLibraryKey': openLibraryKey,
    };
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      isbn: map['isbn'],
      coverUrl: map['coverUrl'],
      pageCount: map['pageCount'],
      publisher: map['publisher'],
      publishYear: map['publishYear'],
      description: map['description'],
      isManuallyAdded: map['isManuallyAdded'] ?? false,
      openLibraryKey: map['openLibraryKey'],
    );
  }

  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? isbn,
    String? coverUrl,
    int? pageCount,
    String? publisher,
    int? publishYear,
    String? description,
    bool? isManuallyAdded,
    String? openLibraryKey,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      pageCount: pageCount ?? this.pageCount,
      publisher: publisher ?? this.publisher,
      publishYear: publishYear ?? this.publishYear,
      description: description ?? this.description,
      isManuallyAdded: isManuallyAdded ?? this.isManuallyAdded,
      openLibraryKey: openLibraryKey ?? this.openLibraryKey,
    );
  }
}
