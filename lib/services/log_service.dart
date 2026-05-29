// lib/services/log_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Log tipleri ───────────────────────────────────────────────────────────────

enum LogType {
  bookAdded,
  bookRemoved,
  bookStatusChanged,
  goalCreated,
  goalEdited,
  goalRemoved,
  tradeListingAdded,
  tradeListingRemoved,
  tradeRequestSent,
  tradeRequestReceived,
  tradeRequestAccepted,
  tradeRequestRejected,
  tradeCompleted,
  chatCreated,
  chatDeleted,
}

class ActivityLog {
  final String id;
  final LogType type;
  final String description;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ActivityLog.fromMap(Map<String, dynamic> m) => ActivityLog(
        id: m['id'] ?? '',
        type: LogType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => LogType.bookAdded,
        ),
        description: m['description'] ?? '',
        createdAt: (m['createdAt'] as Timestamp).toDate(),
      );

  /// Log tipine göre ikon ve renk
  static (String emoji, String category) meta(LogType type) {
    switch (type) {
      case LogType.bookAdded:
        return ('📖', 'Kütüphane');
      case LogType.bookRemoved:
        return ('🗑️', 'Kütüphane');
      case LogType.bookStatusChanged:
        return ('🔄', 'Kütüphane');
      case LogType.goalCreated:
        return ('🎯', 'Hedefler');
      case LogType.goalEdited:
        return ('✏️', 'Hedefler');
      case LogType.goalRemoved:
        return ('❌', 'Hedefler');
      case LogType.tradeListingAdded:
        return ('➕', 'Takas');
      case LogType.tradeListingRemoved:
        return ('➖', 'Takas');
      case LogType.tradeRequestSent:
        return ('📤', 'Takas');
      case LogType.tradeRequestReceived:
        return ('📥', 'Takas');
      case LogType.tradeRequestAccepted:
        return ('✅', 'Takas');
      case LogType.tradeRequestRejected:
        return ('❎', 'Takas');
      case LogType.tradeCompleted:
        return ('🤝', 'Takas');
      case LogType.chatCreated:
        return ('💬', 'Sohbet');
      case LogType.chatDeleted:
        return ('🗑️', 'Sohbet');
    }
  }
}

// ── Servis ────────────────────────────────────────────────────────────────────

class LogService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _logsRef(String userId) =>
      _db.collection('users').doc(userId).collection('activityLog');

  /// Log ekle
  Future<void> addLog({
    required String userId,
    required LogType type,
    required String description,
  }) async {
    final ref = _logsRef(userId).doc();
    await ref.set(ActivityLog(
      id: ref.id,
      type: type,
      description: description,
      createdAt: DateTime.now(),
    ).toMap());
  }

  /// Tüm logları stream olarak getir (en yeni üstte)
  Stream<List<ActivityLog>> watchLogs(String userId) {
    return _logsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ActivityLog.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Takas istatistikleri — alınan ve verilen kitap sayısı
  Future<Map<String, int>> getTradeStats(String userId) async {
    try {
      final snap = await _logsRef(userId)
          .where('type', isEqualTo: LogType.tradeCompleted.name)
          .get();

      int received = 0;
      int given = 0;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final desc = data['description'] as String? ?? '';

        final receivedMatch =
            RegExp(r'Alınan:\s*(.+?)\.').firstMatch(desc);
        final givenMatch =
            RegExp(r'Verilen:\s*(.+?)\.').firstMatch(desc);

        if (receivedMatch != null) {
          final items = receivedMatch.group(1)!.split(',');
          received += items.where((s) => s.trim().isNotEmpty).length;
        }
        if (givenMatch != null) {
          final items = givenMatch.group(1)!.split(',');
          given += items.where((s) => s.trim().isNotEmpty).length;
        }
      }

      return {'received': received, 'given': given};
    } catch (_) {
      return {'received': 0, 'given': 0};
    }
  }

  // ── Hazır log mesajları ───────────────────────────────────────────────────

  String bookAdded(String title, String status) =>
      '"$title" kitabı kütüphaneye eklendi. Durum: $status.';

  String bookRemoved(String title) =>
      '"$title" kitabı kütüphaneden kaldırıldı.';

  String bookStatusChanged(String title, String from, String to) =>
      '"$title" kitabının durumu "$from" → "$to" olarak güncellendi.';

  String goalCreated(String period, String type, int count) =>
      '$period $type hedefi oluşturuldu. Hedef: $count ${type == "Kitap" ? "kitap" : "sayfa"}.';

  String goalEdited(String period, String type, int count) =>
      '$period $type hedefi güncellendi. Yeni hedef: $count ${type == "Kitap" ? "kitap" : "sayfa"}.';

  String goalRemoved(String period, String type) =>
      '$period $type hedefi kaldırıldı.';

  String tradeListingAdded(String title, String city, String district) =>
      '"$title" takasa eklendi. Konum: $city / $district.';

  String tradeListingRemoved(String title) =>
      '"$title" takas listesinden kaldırıldı.';

  String tradeRequestSent(String toUser, String targetBook, List<String> offeredBooks) =>
      'Takas teklifi gönderildi. Kullanıcı: $toUser. İstenen: "$targetBook". Teklif edilen: ${offeredBooks.map((b) => '"$b"').join(', ')}.';

  String tradeRequestReceived(String fromUser, String targetBook, List<String> offeredBooks) =>
      'Takas teklifi alındı. Kullanıcı: $fromUser. İstenen: "$targetBook". Teklif edilen: ${offeredBooks.map((b) => '"$b"').join(', ')}.';

  String tradeRequestAccepted(String fromUser, String targetBook) =>
      '"$fromUser" kullanıcısının "$targetBook" için teklifi kabul edildi.';

  String tradeRequestRejected(String fromUser, String targetBook) =>
      '"$fromUser" kullanıcısının "$targetBook" için teklifi reddedildi.';

  String tradeCompleted(String otherUser, List<String> given, List<String> received) =>
      'Takas tamamlandı. Kullanıcı: $otherUser. Verilen: ${given.map((b) => '"$b"').join(', ')}. Alınan: ${received.map((b) => '"$b"').join(', ')}.';

  String chatCreated(String otherUser) =>
      '"$otherUser" ile sohbet oluşturuldu.';

  String chatDeleted(String otherUser) =>
      '"$otherUser" ile sohbet silindi.';

  /// Durum adını Türkçeye çevir
  static String statusName(String status) {
    switch (status) {
      case 'read': return 'Okudum';
      case 'reading': return 'Okuyorum';
      case 'wantToRead': return 'Okunacak';
      default: return status;
    }
  }
}