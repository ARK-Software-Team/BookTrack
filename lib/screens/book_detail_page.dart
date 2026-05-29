// lib/screens/book_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/book_model.dart';
import '../models/user_book_model.dart';
import '../services/firestore_service.dart';
import '../services/trade_service.dart';
import '../services/log_service.dart';
import '../data/turkey_locations.dart';

class BookDetailPage extends StatefulWidget {
  final UserBookModel userBook;
  const BookDetailPage({super.key, required this.userBook});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final FirestoreService _fs = FirestoreService();
  late UserBookModel _userBook;

  @override
  void initState() {
    super.initState();
    _userBook = widget.userBook;
  }

  String get _userId =>
      Provider.of<AuthService>(context, listen: false).user!.uid;

  // ─── Durum güncelle ────────────────────────────────────────────────────────

  Future<void> _changeStatus(ReadingStatus newStatus) async {
    final oldStatus = _userBook.status;
    if (oldStatus == newStatus) return;

    DateTime? startedAt = _userBook.startedAt;
    DateTime? finishedAt = _userBook.finishedAt;

    if (newStatus == ReadingStatus.reading && startedAt == null) {
      startedAt = DateTime.now();
    }
    if (newStatus == ReadingStatus.read && finishedAt == null) {
      finishedAt = DateTime.now();
    }

    await _fs.updateBookStatus(
      userId: _userId,
      userBookId: _userBook.id,
      oldStatus: oldStatus,
      newStatus: newStatus,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );

    // Log
    await _fs.logStatusChange(
      userId: _userId,
      bookTitle: _userBook.book.title,
      oldStatus: oldStatus,
      newStatus: newStatus,
    );

    setState(() {
      _userBook = _userBook.copyWith(
          status: newStatus,
          startedAt: startedAt,
          finishedAt: finishedAt);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durum güncellendi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Puan & yorum ──────────────────────────────────────────────────────────

  void _showRatingDialog() {
    double tempRating = _userBook.rating ?? 3.0;
    final reviewController =
        TextEditingController(text: _userBook.review ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Puan ve Yorum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Puanın:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < tempRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () =>
                        setDialogState(() => tempRating = (i + 1).toDouble()),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Yorumun (isteğe bağlı)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _fs.updateRatingAndReview(
                  userId: _userId,
                  userBookId: _userBook.id,
                  rating: tempRating,
                  review: reviewController.text.trim().isEmpty
                      ? null
                      : reviewController.text.trim(),
                  bookTitle: _userBook.book.title,
                );
                setState(() {
                  _userBook = _userBook.copyWith(
                    rating: tempRating,
                    review: reviewController.text.trim().isEmpty
                        ? null
                        : reviewController.text.trim(),
                  );
                });
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sayfa güncelle ────────────────────────────────────────────────────────

  void _showPageUpdateDialog() {
    final controller = TextEditingController(
        text: _userBook.currentPage > 0
            ? '${_userBook.currentPage}'
            : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayfa Güncelle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Şu anki sayfa',
            suffixText: _userBook.book.pageCount != null
                ? '/ ${_userBook.book.pageCount}'
                : null,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            onPressed: () async {
              final newPage = int.tryParse(controller.text.trim());
              if (newPage == null || newPage < 0) return;
              Navigator.pop(ctx);

              final pagesRead = (newPage - _userBook.currentPage)
                  .clamp(0, newPage);

              if (pagesRead > 0) {
                final session = ReadingSession(
                  date: DateTime.now(),
                  pagesRead: pagesRead,
                );
                await _fs.addReadingSession(
                  userId: _userId,
                  userBookId: _userBook.id,
                  session: session,
                  newCurrentPage: newPage,
                  bookTitle: _userBook.book.title,
                );
              } else {
                await _fs.updateBookStatus(
                  userId: _userId,
                  userBookId: _userBook.id,
                  oldStatus: _userBook.status,
                  newStatus: _userBook.status,
                  currentPage: newPage,
                );
              }

              setState(() {
                _userBook = _userBook.copyWith(currentPage: newPage);
              });
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ─── Kitabı sil ────────────────────────────────────────────────────────────

  void _showAddToTradeSheet(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.user!.uid;
    final displayName = auth.displayName?.isNotEmpty == true
        ? auth.displayName!
        : auth.user?.email?.split('@').first ?? 'Kullanıcı';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddToTradeSheet(
        userBook: _userBook,
        userId: userId,
        displayName: displayName,
        preferredCity: auth.preferredCity,
        preferredDistrict: auth.preferredDistrict,
      ),
    );
  }

  Future<void> _deleteBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitabı Kaldır'),
        content: Text(
            '"${_userBook.book.title}" kitabını kütüphanenden kaldırmak istiyor musun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _fs.removeBookFromLibrary(
      userId: _userId,
      userBookId: _userBook.id,
      status: _userBook.status,
      bookTitle: _userBook.book.title,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final book = _userBook.book;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Takasa Ekle',
                onPressed: () => _showAddToTradeSheet(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Kitabı Kaldır',
                onPressed: _deleteBook,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Color(0xFF7B1FA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Kapak
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: book.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: book.coverUrl!,
                                  width: 80,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _placeholderCover(80, 120),
                                )
                              : _placeholderCover(80, 120),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                book.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                book.author,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── İçerik ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum kartı
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Okuma Durumu',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _statusChip(ReadingStatus.wantToRead, 'Okunacak',
                                Icons.bookmark_outline, Colors.blue),
                            const SizedBox(width: 8),
                            _statusChip(ReadingStatus.reading, 'Okuyorum',
                                Icons.menu_book, Colors.orange),
                            const SizedBox(width: 8),
                            _statusChip(ReadingStatus.read, 'Okudum',
                                Icons.check_circle_outline, Colors.green),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // İlerleme (okuyorum ise)
                  if (_userBook.status == ReadingStatus.reading) ...[
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Okuma İlerlemesi',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              TextButton.icon(
                                onPressed: _showPageUpdateDialog,
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Güncelle'),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.deepPurple),
                              ),
                            ],
                          ),
                          if (book.pageCount != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _userBook.progressPercent,
                                backgroundColor: Colors.grey[200],
                                color: Colors.orange,
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    '${_userBook.currentPage} / ${book.pageCount} sayfa',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600])),
                                Text(
                                    '%${(_userBook.progressPercent * 100).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text('Sayfa ${_userBook.currentPage}',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Puan & yorum kartı
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Puanım ve Yorumum',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            TextButton.icon(
                              onPressed: _showRatingDialog,
                              icon: const Icon(Icons.star_outline, size: 16),
                              label: Text(_userBook.rating != null
                                  ? 'Düzenle'
                                  : 'Ekle'),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.deepPurple),
                            ),
                          ],
                        ),
                        if (_userBook.rating != null) ...[
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < _userBook.rating!.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 22,
                              );
                            }),
                          ),
                        ] else
                          Text('Henüz puan vermedin',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                        if (_userBook.review != null &&
                            _userBook.review!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _userBook.review!,
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Kitap bilgileri kartı
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kitap Bilgileri',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        if (book.pageCount != null)
                          _infoRow(Icons.format_list_numbered,
                              '${book.pageCount} sayfa'),
                        if (book.publisher != null)
                          _infoRow(Icons.business, book.publisher!),
                        if (book.publishYear != null)
                          _infoRow(
                              Icons.calendar_today, '${book.publishYear}'),
                        if (book.isbn != null)
                          _infoRow(Icons.tag, 'ISBN: ${book.isbn}'),
                        if (book.isManuallyAdded)
                          _infoRow(Icons.edit_note, 'Manuel eklendi'),
                        if (_userBook.startedAt != null)
                          _infoRow(
                              Icons.play_circle_outline,
                              'Başlandı: ${_formatDate(_userBook.startedAt!)}'),
                        if (_userBook.finishedAt != null)
                          _infoRow(
                              Icons.check_circle_outline,
                              'Bitti: ${_formatDate(_userBook.finishedAt!)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _statusChip(
      ReadingStatus status, String label, IconData icon, Color color) {
    final selected = _userBook.status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeStatus(status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color : Colors.grey[300]!,
                width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 18),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: selected ? color : Colors.grey,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCover(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.book, color: Colors.white54, size: 32),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Takasa Ekle Sheet ─────────────────────────────────────────────────────────

class _AddToTradeSheet extends StatefulWidget {
  final UserBookModel userBook;
  final String userId;
  final String displayName;
  final String? preferredCity;
  final String? preferredDistrict;

  const _AddToTradeSheet({
    required this.userBook, required this.userId, required this.displayName,
    this.preferredCity, this.preferredDistrict,
  });

  @override
  State<_AddToTradeSheet> createState() => _AddToTradeSheetState();
}

class _AddToTradeSheetState extends State<_AddToTradeSheet> {
  final TradeService _ts = TradeService();
  late String? _selectedCity;
  late String? _selectedDistrict;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.preferredCity;
    _selectedDistrict = widget.preferredDistrict;
  }

  Future<String?> _pickLocation(List<String> items, String title, String? selected) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LocationSheet(items: items, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.userBook.book;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Takasa Ekle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Kitap önizleme
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: book.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: book.coverUrl!,
                            width: 40, height: 60, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(book.author,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Şehir',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                    color: Colors.deepPurple)),
            const SizedBox(height: 8),
            _LocTile(
              label: _selectedCity ?? 'Şehir seçin',
              icon: Icons.location_city,
              hasValue: _selectedCity != null,
              onTap: () async {
                final r = await _pickLocation(
                    turkeyProvinces, 'Şehir seçin', _selectedCity);
                if (r != null) setState(() {
                  _selectedCity = r;
                  _selectedDistrict = null;
                });
              },
            ),
            const SizedBox(height: 12),
            const Text('İlçe',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                    color: Colors.deepPurple)),
            const SizedBox(height: 8),
            _LocTile(
              label: _selectedDistrict ??
                  (_selectedCity == null ? 'Önce şehir seçin' : 'İlçe seçin'),
              icon: Icons.location_on,
              hasValue: _selectedDistrict != null,
              enabled: _selectedCity != null,
              onTap: _selectedCity == null ? null : () async {
                final r = await _pickLocation(
                    districtsOf(_selectedCity!), 'İlçe seçin', _selectedDistrict);
                if (r != null) setState(() => _selectedDistrict = r);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_saving || _selectedCity == null || _selectedDistrict == null)
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await _ts.addListing(
                          userId: widget.userId,
                          userDisplayName: widget.displayName,
                          bookId: widget.userBook.id,
                          title: book.title,
                          author: book.author,
                          coverUrl: book.coverUrl,
                          pageCount: book.pageCount,
                          city: _selectedCity!,
                          district: _selectedDistrict!,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kitap takas listesine eklendi!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                child: _saving
                    ? const SizedBox(height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Takasa Ekle', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 40, height: 60,
    decoration: BoxDecoration(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.book, color: Colors.deepPurple, size: 20),
  );
}

class _LocTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool hasValue;
  final bool enabled;
  final VoidCallback? onTap;

  const _LocTile({required this.label, required this.icon,
    this.hasValue = false, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          border: Border.all(
              color: hasValue ? Colors.deepPurple : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
          color: enabled ? Colors.white : Colors.grey[50],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: hasValue ? Colors.deepPurple : Colors.grey[400], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(
                color: hasValue ? Colors.black87 : Colors.grey[400], fontSize: 14)),
            ),
            Icon(Icons.arrow_drop_down,
                color: enabled ? Colors.grey : Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  final List<String> items;
  final String? selected;
  const _LocationSheet({required this.items, this.selected});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.items
            : widget.items.where((i) => i.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _ctrl, autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final item = _filtered[i];
                final sel = item == widget.selected;
                return ListTile(
                  title: Text(item),
                  trailing: sel ? const Icon(Icons.check, color: Colors.deepPurple) : null,
                  selected: sel, selectedColor: Colors.deepPurple,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}