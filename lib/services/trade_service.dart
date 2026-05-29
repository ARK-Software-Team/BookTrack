// lib/services/trade_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'log_service.dart';

// ── Veri modelleri ────────────────────────────────────────────────────────────

class TradeListing {
  final String id;
  final String userId;
  final String userDisplayName;
  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;
  final int? pageCount;
  final String city;
  final String district;
  final DateTime createdAt;
  final bool isActive;

  TradeListing({
    required this.id, required this.userId, required this.userDisplayName,
    required this.bookId, required this.title, required this.author,
    this.coverUrl, this.pageCount, required this.city, required this.district,
    required this.createdAt, this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'userId': userId, 'userDisplayName': userDisplayName,
    'bookId': bookId, 'title': title, 'author': author,
    'coverUrl': coverUrl, 'pageCount': pageCount,
    'city': city, 'district': district,
    'createdAt': Timestamp.fromDate(createdAt), 'isActive': isActive,
  };

  factory TradeListing.fromMap(Map<String, dynamic> m) => TradeListing(
    id: m['id'] ?? '', userId: m['userId'] ?? '',
    userDisplayName: m['userDisplayName'] ?? '',
    bookId: m['bookId'] ?? '', title: m['title'] ?? '', author: m['author'] ?? '',
    coverUrl: m['coverUrl'], pageCount: m['pageCount'],
    city: m['city'] ?? '', district: m['district'] ?? '',
    createdAt: (m['createdAt'] as Timestamp).toDate(),
    isActive: m['isActive'] ?? true,
  );
}

class TradeRequest {
  final String id;
  final String fromUserId;
  final String fromUserDisplayName;
  final String toUserId;
  final String toUserDisplayName;
  final String targetListingId;
  final String targetBookTitle;
  final List<Map<String, dynamic>> offeredBooks;
  final String status;
  final DateTime createdAt;

  TradeRequest({
    required this.id, required this.fromUserId, required this.fromUserDisplayName,
    required this.toUserId, this.toUserDisplayName = '', required this.targetListingId,
    required this.targetBookTitle, required this.offeredBooks,
    required this.status, required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'fromUserId': fromUserId,
    'fromUserDisplayName': fromUserDisplayName,
    'toUserId': toUserId, 'toUserDisplayName': toUserDisplayName, 'targetListingId': targetListingId,
    'targetBookTitle': targetBookTitle, 'offeredBooks': offeredBooks,
    'status': status, 'createdAt': Timestamp.fromDate(createdAt),
  };

  factory TradeRequest.fromMap(Map<String, dynamic> m) => TradeRequest(
    id: m['id'] ?? '', fromUserId: m['fromUserId'] ?? '',
    fromUserDisplayName: m['fromUserDisplayName'] ?? '',
    toUserId: m['toUserId'] ?? '',
    toUserDisplayName: m['toUserDisplayName'] as String? ?? '',
    targetListingId: m['targetListingId'] ?? '',
    targetBookTitle: m['targetBookTitle'] ?? '',
    offeredBooks: List<Map<String, dynamic>>.from(m['offeredBooks'] ?? []),
    status: m['status'] ?? 'pending',
    createdAt: (m['createdAt'] as Timestamp).toDate(),
  );
}

class TradeChat {
  final String id;
  final List<String> participants;
  final String requestId;
  final String otherUserId;
  final String otherUserDisplayName;
  final List<String> confirmedBy;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String targetBookTitle;
  final String targetListingUserId;
  final List<Map<String, dynamic>> offeredListings;

  TradeChat({
    required this.id, required this.participants, required this.requestId,
    required this.otherUserId, required this.otherUserDisplayName,
    required this.confirmedBy, required this.createdAt,
    this.lastMessage, this.lastMessageAt,
    this.targetBookTitle = '',
    this.targetListingUserId = '',
    this.offeredListings = const [],
  });

  factory TradeChat.fromMap(Map<String, dynamic> m, String currentUserId) {
    final participants = List<String>.from(m['participants'] ?? []);
    final otherUserId =
        participants.firstWhere((p) => p != currentUserId, orElse: () => '');
    final displayNames = (m['displayNames'] as Map<String, dynamic>?) ?? {};
    return TradeChat(
      id: m['id'] ?? '', participants: participants,
      requestId: m['requestId'] ?? '', otherUserId: otherUserId,
      otherUserDisplayName: displayNames[otherUserId] as String? ?? 'Kullanıcı',
      confirmedBy: List<String>.from(m['confirmedBy'] ?? []),
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      lastMessage: m['lastMessage'] as String?,
      lastMessageAt: (m['lastMessageAt'] as Timestamp?)?.toDate(),
      targetBookTitle: m['targetBookTitle'] as String? ?? '',
      targetListingUserId: m['targetListingUserId'] as String? ?? '',
      offeredListings: List<Map<String, dynamic>>.from(m['offeredListings'] ?? []),
    );
  }
}

class TradeMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isSystem; // sistem mesajı (kullanıcı sildi bildirimi)

  TradeMessage({
    required this.id, required this.senderId, required this.senderName,
    required this.text, required this.createdAt, this.isSystem = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'senderId': senderId, 'senderName': senderName,
    'text': text, 'createdAt': Timestamp.fromDate(createdAt),
    'isSystem': isSystem,
  };

  factory TradeMessage.fromMap(Map<String, dynamic> m) => TradeMessage(
    id: m['id'] ?? '', senderId: m['senderId'] ?? '',
    senderName: m['senderName'] ?? '', text: m['text'] ?? '',
    createdAt: (m['createdAt'] as Timestamp).toDate(),
    isSystem: m['isSystem'] ?? false,
  );
}

// ── Servis ────────────────────────────────────────────────────────────────────

class TradeService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _listings => _db.collection('tradeListings');
  CollectionReference get _requests => _db.collection('tradeRequests');
  CollectionReference get _chats => _db.collection('tradeChats');

  // ─── Listing ─────────────────────────────────────────────────────────────

  Stream<List<TradeListing>> watchMyListings(String userId) {
    return _listings
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TradeListing.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addListing({
    required String userId, required String userDisplayName,
    required String bookId, required String title, required String author,
    String? coverUrl, int? pageCount,
    required String city, required String district,
  }) async {
    final ref = _listings.doc();
    await ref.set(TradeListing(
      id: ref.id, userId: userId, userDisplayName: userDisplayName,
      bookId: bookId, title: title, author: author,
      coverUrl: coverUrl, pageCount: pageCount,
      city: city, district: district, createdAt: DateTime.now(),
    ).toMap());

    // Log
    final ls = LogService();
    await ls.addLog(
      userId: userId,
      type: LogType.tradeListingAdded,
      description: ls.tradeListingAdded(title, city, district),
    );
  }

  /// Kendi listing'ini pasif yap (her zaman izinli)
  Future<void> removeListing(String listingId, {String? userId, String? bookTitle}) async {
    await _listings.doc(listingId).update({'isActive': false});

    // Log
    if (userId != null && bookTitle != null) {
      final ls = LogService();
      await ls.addLog(
        userId: userId,
        type: LogType.tradeListingRemoved,
        description: ls.tradeListingRemoved(bookTitle),
      );
    }
  }

  // ─── Arama ──────────────────────────────────────────────────────────────

  Future<List<TradeListing>> searchListings({
    required String city,
    String? district, // null = tüm şehir
    required String excludeUserId,
    String? query,
  }) async {
    Query q = _listings
        .where('city', isEqualTo: city)
        .where('isActive', isEqualTo: true);

    // İlçe seçildiyse filtrele
    if (district != null) {
      q = q.where('district', isEqualTo: district);
    }

    final snap = await q.get();

    var results = snap.docs
        .map((d) => TradeListing.fromMap(d.data() as Map<String, dynamic>))
        .where((l) => l.userId != excludeUserId)
        .toList();

    if (query != null && query.trim().isNotEmpty) {
      final qLower = query.toLowerCase();
      results = results
          .where((l) =>
              l.title.toLowerCase().contains(qLower) ||
              l.author.toLowerCase().contains(qLower))
          .toList();
    }
    return results;
  }

  /// 1 aydan eski reddedilen teklifleri temizle
  Future<void> cleanOldRejectedRequests(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final snap = await _requests
        .where('status', isEqualTo: 'rejected')
        .where('fromUserId', isEqualTo: userId)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && createdAt.isBefore(cutoff)) {
        await doc.reference.delete();
      }
    }
    // Ayrıca gelen reddedilenler
    final snap2 = await _requests
        .where('status', isEqualTo: 'rejected')
        .where('toUserId', isEqualTo: userId)
        .get();
    for (final doc in snap2.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null && createdAt.isBefore(cutoff)) {
        await doc.reference.delete();
      }
    }
  }

  // ─── Teklifler ───────────────────────────────────────────────────────────

  Future<void> sendTradeRequest({
    required String fromUserId, required String fromUserDisplayName,
    required String toUserId, required String toUserDisplayName,
    required String targetListingId,
    required String targetBookTitle, required List<Map<String, dynamic>> offeredBooks,
  }) async {
    final ref = _requests.doc();
    await ref.set(TradeRequest(
      id: ref.id, fromUserId: fromUserId,
      fromUserDisplayName: fromUserDisplayName, toUserId: toUserId, toUserDisplayName: toUserDisplayName,
      targetListingId: targetListingId, targetBookTitle: targetBookTitle,
      offeredBooks: offeredBooks, status: 'pending', createdAt: DateTime.now(),
    ).toMap());

    // Log — try/catch ile butonun takılmaması sağlanır
    try {
      final ls = LogService();
      final offeredTitles = offeredBooks.map((b) => b['title'] as String? ?? '').toList();
      await ls.addLog(
        userId: fromUserId,
        type: LogType.tradeRequestSent,
        description: ls.tradeRequestSent(toUserDisplayName, targetBookTitle, offeredTitles),
      );
      await ls.addLog(
        userId: toUserId,
        type: LogType.tradeRequestReceived,
        description: ls.tradeRequestReceived(fromUserDisplayName, targetBookTitle, offeredTitles),
      );
    } catch (_) {}
  }

  Stream<List<TradeRequest>> watchIncomingRequests(String userId) {
    return _requests
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TradeRequest.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<int> watchIncomingRequestCount(String userId) =>
      watchIncomingRequests(userId).map((list) => list.length);

  /// Gönderilen teklifler (bekleyen + kabul + red)
  Stream<List<TradeRequest>> watchOutgoingRequests(String userId) {
    return _requests
        .where('fromUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TradeRequest.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<String> acceptRequest({
    required TradeRequest request, required String myDisplayName,
  }) async {
    await _requests.doc(request.id).update({'status': 'accepted'});

    // Log — try/catch
    try {
      final ls = LogService();
      // Kabul eden
      await ls.addLog(
        userId: request.toUserId,
        type: LogType.tradeRequestAccepted,
        description: ls.tradeRequestAccepted(request.fromUserDisplayName, request.targetBookTitle),
      );
      // Teklif gönderene bildir
      await ls.addLog(
        userId: request.fromUserId,
        type: LogType.tradeRequestAccepted,
        description: '"${request.targetBookTitle}" için teklifin kabul edildi. Kullanıcı: $myDisplayName.',
      );
      // Sohbet oluşturuldu
      await ls.addLog(
        userId: request.fromUserId,
        type: LogType.chatCreated,
        description: ls.chatCreated(myDisplayName),
      );
      await ls.addLog(
        userId: request.toUserId,
        type: LogType.chatCreated,
        description: ls.chatCreated(request.fromUserDisplayName),
      );
    } catch (_) {}

    final chatRef = _chats.doc();
    await chatRef.set({
      'id': chatRef.id,
      'participants': [request.fromUserId, request.toUserId],
      'requestId': request.id,
      'confirmedBy': [],
      'deletedBy': [],
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'lastMessage': null,
      'lastMessageAt': null,
      'displayNames': {
        request.fromUserId: request.fromUserDisplayName,
        request.toUserId: myDisplayName,
      },
      'targetListingId': request.targetListingId,
      'targetListingUserId': request.toUserId,
      'targetBookTitle': request.targetBookTitle,
      'offeredListings': request.offeredBooks,
    });
    return chatRef.id;
  }

  Future<void> rejectRequest(String requestId, {
    String? userId, String? fromUser, String? bookTitle,
    String? fromUserId, String? myDisplayName,
  }) async {
    await _requests.doc(requestId).update({'status': 'rejected'});

    try {
      if (userId != null && fromUser != null && bookTitle != null) {
        final ls = LogService();
        // Reddeden
        await ls.addLog(
          userId: userId,
          type: LogType.tradeRequestRejected,
          description: ls.tradeRequestRejected(fromUser, bookTitle),
        );
        // Teklif gönderene bildir
        if (fromUserId != null && myDisplayName != null) {
          await ls.addLog(
            userId: fromUserId,
            type: LogType.tradeRequestRejected,
            description: '"$bookTitle" için teklifin reddedildi. Kullanıcı: $myDisplayName.',
          );
        }
      }
    } catch (_) {}
  }

  // ─── Sohbet ──────────────────────────────────────────────────────────────

  Stream<List<TradeChat>> watchChats(String userId) {
    return _chats
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TradeChat.fromMap(
                d.data() as Map<String, dynamic>, userId))
            .toList());
  }

  Stream<int> watchChatCount(String userId) =>
      watchChats(userId).map((list) => list.length);

  Stream<List<TradeMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => TradeMessage.fromMap(d.data())).toList());
  }

  Future<void> sendMessage({
    required String chatId, required String senderId,
    required String senderName, required String text,
  }) async {
    final msgRef = _chats.doc(chatId).collection('messages').doc();
    final now = DateTime.now();
    await msgRef.set(TradeMessage(
      id: msgRef.id, senderId: senderId, senderName: senderName,
      text: text, createdAt: now,
    ).toMap());
    await _chats.doc(chatId).update({
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(now),
    });
  }

  /// Kullanıcı sohbeti siler:
  /// - Karşı tarafa sistem mesajı gönderir
  /// - Her iki taraf da sildiyse tüm veriyi temizler
  Future<void> deleteChat({
    required String chatId,
    required String userId,
    required String userName,
  }) async {
    final chatDoc = await _chats.doc(chatId).get();
    if (!chatDoc.exists) return;
    final data = chatDoc.data() as Map<String, dynamic>;
    final deletedBy = List<String>.from(data['deletedBy'] ?? []);
    final participants = List<String>.from(data['participants'] ?? []);

    if (!deletedBy.contains(userId)) {
      deletedBy.add(userId);
    }

    // Log önce yaz (doküman silinmeden önce)
    final displayNames = (data['displayNames'] as Map<String, dynamic>?) ?? {};
    final otherUserId = participants.firstWhere((p) => p != userId, orElse: () => '');
    final otherName = displayNames[otherUserId] as String? ?? 'Kullanıcı';
    try {
      final ls = LogService();
      await ls.addLog(
        userId: userId,
        type: LogType.chatDeleted,
        description: ls.chatDeleted(otherName),
      );
    } catch (_) {}

    // Her iki taraf da sildiyse: veriyi temizle
    if (deletedBy.length >= 2 &&
        participants.every((p) => deletedBy.contains(p))) {
      try {
        final msgs = await _chats.doc(chatId).collection('messages').get();
        if (msgs.docs.isEmpty) {
          await _chats.doc(chatId).delete();
        } else {
          const batchSize = 400;
          for (int i = 0; i < msgs.docs.length; i += batchSize) {
            final batch = _db.batch();
            final chunk = msgs.docs.skip(i).take(batchSize);
            for (final msg in chunk) { batch.delete(msg.reference); }
            if (i + batchSize >= msgs.docs.length) {
              batch.delete(_chats.doc(chatId));
            }
            await batch.commit();
          }
        }
      } catch (_) {}
      return;
    }

    // Sadece bu kullanıcı sildi: sistem mesajı gönder, deletedBy güncelle
    await _chats.doc(chatId).update({'deletedBy': deletedBy});

    final msgRef = _chats.doc(chatId).collection('messages').doc();
    final now = DateTime.now();
    await msgRef.set(TradeMessage(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'Sistem',
      text: '$userName sohbeti sildi.',
      createdAt: now,
      isSystem: true,
    ).toMap());
    await _chats.doc(chatId).update({
      'lastMessage': '$userName sohbeti sildi.',
      'lastMessageAt': Timestamp.fromDate(now),
    });
  }

  /// Takas tamamlandı onayı:
  /// Her kullanıcı kendi listing'ini isActive:false yapar.
  /// Her iki taraf onayladıysa sohbet ve mesajlar silinir.
  Future<bool> confirmTrade({
    required String chatId,
    required String userId,
  }) async {
    final chatDoc = await _chats.doc(chatId).get();
    if (!chatDoc.exists) return false;
    final data = chatDoc.data() as Map<String, dynamic>;
    final confirmedBy = List<String>.from(data['confirmedBy'] ?? []);

    if (!confirmedBy.contains(userId)) {
      confirmedBy.add(userId);
      await _chats.doc(chatId).update({'confirmedBy': confirmedBy});
    }

    // Bu kullanıcıya ait listing'leri pasif yap (isActive:false — kendi listing'i)
    final targetListingId = data['targetListingId'] as String?;
    final targetListingUserId = data['targetListingUserId'] as String?;
    final offeredListings =
        List<Map<String, dynamic>>.from(data['offeredListings'] ?? []);

    if (targetListingUserId == userId && targetListingId != null) {
      try {
        await _listings.doc(targetListingId).update({'isActive': false});
      } catch (_) {}
    }

    for (final offered in offeredListings) {
      final listingId = offered['listingId'] as String?;
      if (listingId == null) continue;
      try {
        final doc = await _listings.doc(listingId).get();
        if (doc.exists) {
          final lData = doc.data() as Map<String, dynamic>;
          if (lData['userId'] == userId) {
            await _listings.doc(listingId).update({'isActive': false});
          }
        }
      } catch (_) {}
    }

    final participants = List<String>.from(data['participants'] ?? []);

    if (confirmedBy.length >= 2 &&
        participants.every((p) => confirmedBy.contains(p))) {

      // targetTitle — listing silinmiş olabilir, chat dokümanından al
      final storedTargetTitle =
          data['targetBookTitle'] as String? ?? 'Kitap';
      final displayNames = (data['displayNames'] as Map<String, dynamic>?) ?? {};
      final offeredTitles = offeredListings
          .map((l) => l['title'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toList();

      // Her iki kullanıcı için log — ayrı try/catch, silme işlemini engellemez
      try {
        final ls = LogService();
        for (final participant in participants) {
          final otherUser =
              participants.firstWhere((p) => p != participant);
          final otherName =
              displayNames[otherUser] as String? ?? 'Kullanıcı';
          final isTargetOwner = targetListingUserId == participant;
          final given =
              isTargetOwner ? [storedTargetTitle] : offeredTitles;
          final received =
              isTargetOwner ? offeredTitles : [storedTargetTitle];
          await ls.addLog(
            userId: participant,
            type: LogType.tradeCompleted,
            description: ls.tradeCompleted(otherName, given, received),
          );
        }
      } catch (_) {}

      // Sohbet ve mesajları sil — batch ile hızlı silme
      try {
        final msgs = await _chats.doc(chatId).collection('messages').get();
        if (msgs.docs.isEmpty) {
          await _chats.doc(chatId).delete();
        } else {
          // 500'lük batch limitini aş olmamak için parçala
          const batchSize = 400;
          for (int i = 0; i < msgs.docs.length; i += batchSize) {
            final batch = _db.batch();
            final chunk = msgs.docs.skip(i).take(batchSize);
            for (final msg in chunk) {
              batch.delete(msg.reference);
            }
            if (i + batchSize >= msgs.docs.length) {
              batch.delete(_chats.doc(chatId));
            }
            await batch.commit();
          }
        }
      } catch (e) {
        // Fallback: tek tek sil
        try {
          final msgs = await _chats.doc(chatId).collection('messages').get();
          for (final msg in msgs.docs) { await msg.reference.delete(); }
          await _chats.doc(chatId).delete();
        } catch (_) {}
      }

      return true;
    }
    return false;
  }

  Stream<List<String>> watchConfirmedBy(String chatId) {
    return _chats.doc(chatId).snapshots().map((s) {
      if (!s.exists) return <String>[];
      final data = s.data() as Map<String, dynamic>?;
      return List<String>.from(data?['confirmedBy'] ?? []);
    });
  }
}