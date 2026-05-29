// lib/screens/search_page.dart
// Değişiklikler:
// 1. _getUserId → AuthService kullanıyor (dynamic değil)
// 2. Bottom sheet durum sırası → Okudum / Okuyorum / Okunacak
// 3. Arama gecikmesi azaltıldı: timeout 10s→15s, retry mantığı eklendi

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../services/open_library_service.dart';
import '../services/firestore_service.dart';
import '../models/book_model.dart';
import 'add_book_manual_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final OpenLibraryService _openLibraryService = OpenLibraryService();

  List<OpenLibraryBook> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _hasSearched = true;
      _errorMessage = null;
      _results = [];
    });

    // İlk denemede boş gelirse bir kez daha dene
    List<OpenLibraryBook> results = await _openLibraryService.searchBooks(query, limit: 15);
    if (results.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      results = await _openLibraryService.searchBooks(query, limit: 15);
    }

    setState(() {
      _loading = false;
      _results = results;
      if (results.isEmpty) {
        _errorMessage = 'Sonuç bulunamadı. Manuel olarak ekleyebilirsin.';
      }
    });
  }

  Future<void> _addToLibrary(
      BuildContext context, OpenLibraryBook olBook, ReadingStatus status) async {
    final book = BookModel(
      id: '',
      title: olBook.title,
      author: olBook.author,
      isbn: olBook.isbn,
      coverUrl: olBook.coverUrl,
      pageCount: olBook.pageCount,
      publisher: olBook.publisher,
      publishYear: olBook.publishYear,
      isManuallyAdded: false,
      openLibraryKey: olBook.openLibraryKey,
    );

    final userId = _getUserId(context);
    if (userId == null) return;

    try {
      await FirestoreService().addBookToLibrary(userId: userId, book: book, status: status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${olBook.title}" kütüphaneye eklendi!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kitap eklenirken bir hata oluştu.'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String? _getUserId(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.user?.uid;
  }

  void _showStatusPicker(BuildContext context, OpenLibraryBook book) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(book.author, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const Divider(height: 24),
            const Text('Kütüphaneye hangi durumda ekleyelim?',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            // Sıra: Okudum → Okuyorum → Okunacak
            _statusTile(ctx, book,
                icon: Icons.check_circle_outline, label: 'Okudum',
                color: Colors.green, status: ReadingStatus.read),
            _statusTile(ctx, book,
                icon: Icons.menu_book, label: 'Şu an okuyorum',
                color: Colors.orange, status: ReadingStatus.reading),
            _statusTile(ctx, book,
                icon: Icons.bookmark_outline, label: 'Okunacak',
                color: Colors.blue, status: ReadingStatus.wantToRead),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(BuildContext ctx, OpenLibraryBook book,
      {required IconData icon, required String label,
       required Color color, required ReadingStatus status}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: () {
        Navigator.pop(ctx);
        _addToLibrary(context, book, status);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.deepPurple,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Kitap adı veya yazar...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Ara'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'search_fab',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddBookManualPage())),
        icon: const Icon(Icons.add),
        label: const Text('Manuel Ekle'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 12),
            Text('Kitaplar aranıyor...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Kitap adı veya yazar yazıp ara',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 8),
            Text("Open Library'den milyonlarca kitaba ulaş",
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddBookManualPage())),
                icon: const Icon(Icons.edit),
                label: const Text('Manuel Ekle'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = _results[index];
        return _BookCard(book: book, onAdd: () => _showStatusPicker(context, book));
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final OpenLibraryBook book;
  final VoidCallback onAdd;
  const _BookCard({required this.book, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: book.coverUrl!,
                      width: 60, height: 90, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholderCover())
                  : _placeholderCover(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(book.author, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (book.publishYear != null) ...[
                        Icon(Icons.calendar_today, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text('${book.publishYear}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 10),
                      ],
                      if (book.pageCount != null) ...[
                        Icon(Icons.menu_book, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text('${book.pageCount} sayfa',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                  if (book.publisher != null) ...[
                    const SizedBox(height: 2),
                    Text(book.publisher!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
              iconSize: 32, tooltip: 'Kütüphaneye ekle',
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCover() => Container(
    width: 60, height: 90,
    decoration: BoxDecoration(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.book, color: Colors.deepPurple, size: 30),
  );
}