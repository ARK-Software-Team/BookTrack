// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';
import 'log_service.dart';
import '../models/user_book_model.dart';
import '../models/reading_goal_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Koleksiyon referansları ───────────────────────────────────────────────

  CollectionReference _userBooksRef(String userId) =>
      _db.collection('users').doc(userId).collection('userBooks');

  CollectionReference _goalsRef(String userId) =>
      _db.collection('users').doc(userId).collection('readingGoals');

  DocumentReference _userDocRef(String userId) =>
      _db.collection('users').doc(userId);

  // ─── Kullanıcı Profili ─────────────────────────────────────────────────────

  /// Yeni kayıt sonrası kullanıcı dokümanını oluşturur
  Future<void> createUserProfile({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    await _userDocRef(userId).set({
      'userId': userId,
      'email': email,
      'displayName': displayName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // İstatistik özeti (hızlı okuma için denormalize)
      'stats': {
        'totalBooks': 0,
        'booksRead': 0,
        'currentlyReading': 0,
        'wantToRead': 0,
        'totalPagesRead': 0,
      },
    }, SetOptions(merge: true));
  }

  // ─── Kitaplık (UserBooks) CRUD ─────────────────────────────────────────────

  /// Kullanıcı kütüphanesine kitap ekler
  Future<UserBookModel> addBookToLibrary({
    required String userId,
    required BookModel book,
    ReadingStatus status = ReadingStatus.wantToRead,
  }) async {
    final now = DateTime.now();
    final docRef = _userBooksRef(userId).doc();

    final userBook = UserBookModel(
      id: docRef.id,
      userId: userId,
      book: book.copyWith(id: book.id.isEmpty ? docRef.id : book.id),
      status: status,
      currentPage: 0,
      addedAt: now,
      updatedAt: now,
    );

    await docRef.set(userBook.toMap());

    // İstatistikleri güncelle
    await _incrementStats(userId, status);

    // Log
    final ls = LogService();
    await ls.addLog(
      userId: userId,
      type: LogType.bookAdded,
      description: ls.bookAdded(book.title, LogService.statusName(status.name)),
    );

    return userBook;
  }

  /// Kitap durumunu günceller (wantToRead → reading → read gibi)
  Future<void> updateBookStatus({
    required String userId,
    required String userBookId,
    required ReadingStatus oldStatus,
    required ReadingStatus newStatus,
    int? currentPage,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final now = DateTime.now();
    final Map<String, dynamic> updates = {
      'status': newStatus.name,
      'updatedAt': Timestamp.fromDate(now),
    };

    if (currentPage != null) updates['currentPage'] = currentPage;
    if (startedAt != null) updates['startedAt'] = Timestamp.fromDate(startedAt);
    if (finishedAt != null) updates['finishedAt'] = Timestamp.fromDate(finishedAt);

    await _userBooksRef(userId).doc(userBookId).update(updates);

    // İstatistik düzeltmesi
    if (oldStatus != newStatus) {
      await _adjustStats(userId, oldStatus, newStatus);
    }
  }

  /// Durum değişikliğini loglar (bookTitle gerekli)
  Future<void> logStatusChange({
    required String userId,
    required String bookTitle,
    required ReadingStatus oldStatus,
    required ReadingStatus newStatus,
  }) async {
    final ls = LogService();
    await ls.addLog(
      userId: userId,
      type: LogType.bookStatusChanged,
      description: ls.bookStatusChanged(
        bookTitle,
        LogService.statusName(oldStatus.name),
        LogService.statusName(newStatus.name),
      ),
    );
  }

  /// Puan ve yorum ekler/günceller
  Future<void> updateRatingAndReview({
    required String userId,
    required String userBookId,
    double? rating,
    String? review,
    String? bookTitle,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (rating != null) updates['rating'] = rating;
    if (review != null) updates['review'] = review;

    await _userBooksRef(userId).doc(userBookId).update(updates);

    // Log
    if (bookTitle != null) {
      final ls = LogService();
      if (rating != null) {
        await ls.addLog(
          userId: userId,
          type: LogType.bookStatusChanged,
          description: '\"$bookTitle\" kitabına $rating yıldız puan verildi.',
        );
      }
      if (review != null && review.isNotEmpty) {
        await ls.addLog(
          userId: userId,
          type: LogType.bookStatusChanged,
          description: '\"$bookTitle\" kitabına yorum eklendi: \"$review\"',
        );
      }
    }
  }

  /// Okuma seansı ekler ve mevcut sayfayı günceller
  Future<void> addReadingSession({
    required String userId,
    required String userBookId,
    required ReadingSession session,
    required int newCurrentPage,
    String? bookTitle,
  }) async {
    await _userBooksRef(userId).doc(userBookId).update({
      'currentPage': newCurrentPage,
      'readingSessions': FieldValue.arrayUnion([session.toMap()]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Toplam okunan sayfayı stats'a ekle
    await _userDocRef(userId).update({
      'stats.totalPagesRead': FieldValue.increment(session.pagesRead),
    });

    // Log
    if (bookTitle != null) {
      final ls = LogService();
      await ls.addLog(
        userId: userId,
        type: LogType.bookStatusChanged,
        description: '\"$bookTitle\" kitabında sayfa ${newCurrentPage - session.pagesRead} → $newCurrentPage güncellendi (${session.pagesRead} sayfa okundu).',
      );
    }
  }

  /// Kitabı kütüphaneden kaldırır
  Future<void> removeBookFromLibrary({
    required String userId,
    required String userBookId,
    required ReadingStatus status,
    String? bookTitle,
  }) async {
    await _userBooksRef(userId).doc(userBookId).delete();
    await _decrementStats(userId, status);

    // Log
    if (bookTitle != null) {
      final ls = LogService();
      await ls.addLog(
        userId: userId,
        type: LogType.bookRemoved,
        description: ls.bookRemoved(bookTitle),
      );
    }
  }

  // ─── Sorgular ─────────────────────────────────────────────────────────────

  /// Tüm kitapları stream olarak dinler
  Stream<List<UserBookModel>> watchAllBooks(String userId) {
    return _userBooksRef(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserBookModel.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Belirli statüsteki kitapları stream olarak dinler
  Stream<List<UserBookModel>> watchBooksByStatus(
      String userId, ReadingStatus status) {
    return _userBooksRef(userId)
        .where('status', isEqualTo: status.name)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserBookModel.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Belirli yılda tamamlanan kitaplar (yıllık hedef takibi için)
  Future<List<UserBookModel>> getBooksFinishedInYear(
      String userId, int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);

    final snap = await _userBooksRef(userId)
        .where('status', isEqualTo: ReadingStatus.read.name)
        .where('finishedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('finishedAt', isLessThan: Timestamp.fromDate(end))
        .get();

    return snap.docs
        .map((d) => UserBookModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  /// Belirli aralıkta okunan sayfaları hesaplar (istatistik)
  Future<int> getTotalPagesInRange(
      String userId, DateTime from, DateTime to) async {
    final snap = await _userBooksRef(userId).get();
    int total = 0;

    for (final doc in snap.docs) {
      final userBook =
          UserBookModel.fromMap(doc.data() as Map<String, dynamic>);
      for (final session in userBook.readingSessions) {
        if (session.date.isAfter(from) && session.date.isBefore(to)) {
          total += session.pagesRead;
        }
      }
    }
    return total;
  }

  // ─── Okuma Hedefleri ──────────────────────────────────────────────────────

  /// Hedef oluşturur veya mevcut hedefi günceller
  Future<void> setReadingGoal(ReadingGoalModel goal) async {
    // Aynı period+type+year kombinasyonu varsa üzerine yazar
    final existing = await _goalsRef(goal.userId)
        .where('period', isEqualTo: goal.period.name)
        .where('type', isEqualTo: goal.type.name)
        .where('year', isEqualTo: goal.year)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'targetCount': goal.targetCount,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      final docRef = _goalsRef(goal.userId).doc();
      await docRef.set(goal.copyWith(id: docRef.id).toMap());
    }
  }

  /// Tüm hedefleri stream olarak dinler
  Stream<List<ReadingGoalModel>> watchGoals(String userId) {
    return _goalsRef(userId).snapshots().map((snap) => snap.docs
        .map((d) =>
            ReadingGoalModel.fromMap(d.data() as Map<String, dynamic>))
        .toList());
  }

  // ─── İstatistik Yardımcıları ──────────────────────────────────────────────

  Future<void> _incrementStats(String userId, ReadingStatus status) async {
    final field = _statsFieldForStatus(status);
    await _userDocRef(userId).update({
      'stats.totalBooks': FieldValue.increment(1),
      'stats.$field': FieldValue.increment(1),
    });
  }

  Future<void> _decrementStats(String userId, ReadingStatus status) async {
    final field = _statsFieldForStatus(status);
    await _userDocRef(userId).update({
      'stats.totalBooks': FieldValue.increment(-1),
      'stats.$field': FieldValue.increment(-1),
    });
  }

  Future<void> _adjustStats(
      String userId, ReadingStatus from, ReadingStatus to) async {
    final fromField = _statsFieldForStatus(from);
    final toField = _statsFieldForStatus(to);
    await _userDocRef(userId).update({
      'stats.$fromField': FieldValue.increment(-1),
      'stats.$toField': FieldValue.increment(1),
      if (to == ReadingStatus.read)
        'stats.booksRead': FieldValue.increment(1),
    });
  }

  String _statsFieldForStatus(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.wantToRead:
        return 'wantToRead';
      case ReadingStatus.reading:
        return 'currentlyReading';
      case ReadingStatus.read:
        return 'booksRead';
    }
  }
}