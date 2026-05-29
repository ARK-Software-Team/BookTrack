// lib/screens/library_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../models/book_model.dart';
import '../models/user_book_model.dart';
import '../services/firestore_service.dart';
import 'book_detail_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // Başlık yok — sadece TabBar
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          toolbarHeight: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.check_circle_outline, size: 18), text: 'Okudum'),
              Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Okuyorum'),
              Tab(icon: Icon(Icons.bookmark_outline, size: 18), text: 'Okunacak'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookList(status: ReadingStatus.read),
            _BookList(status: ReadingStatus.reading),
            _BookList(status: ReadingStatus.wantToRead),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatefulWidget {
  final ReadingStatus status;
  const _BookList({required this.status});

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthService>(context, listen: false).user?.uid;
    if (userId == null) return const SizedBox();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Kitap veya yazar ara...',
              prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserBookModel>>(
            stream: FirestoreService().watchBooksByStatus(userId, widget.status),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple));
              }
              var books = snapshot.data ?? [];

              if (_query.isNotEmpty) {
                books = books
                    .where((b) =>
                        b.book.title.toLowerCase().contains(_query) ||
                        b.book.author.toLowerCase().contains(_query))
                    .toList();
              }

              books.sort((a, b) => a.book.title
                  .toLowerCase()
                  .compareTo(b.book.title.toLowerCase()));

              if (books.isEmpty) {
                return _query.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 52, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('"$_query" için sonuç bulunamadı',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : _EmptyState(status: widget.status);
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _BookTile(userBook: books[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ReadingStatus status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (status) {
      ReadingStatus.read => (Icons.check_circle_outline, 'Henüz kitap okumadın',
          'Okuduğun kitapları burada göreceksin'),
      ReadingStatus.reading => (Icons.menu_book, 'Şu an okuduğun kitap yok',
          'Kütüphaneye kitap ekleyip\n"Okuyorum" olarak işaretle'),
      ReadingStatus.wantToRead => (Icons.bookmark_outline,
          'Okumak istediğin kitap yok', 'Arama yaparak kitap ekle'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final UserBookModel userBook;
  const _BookTile({required this.userBook});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => BookDetailPage(userBook: userBook))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: userBook.book.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: userBook.book.coverUrl!,
                        width: 52, height: 78, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _cover())
                    : _cover(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userBook.book.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(userBook.book.author,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                    if (userBook.status == ReadingStatus.reading &&
                        userBook.book.pageCount != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: userBook.progressPercent,
                                backgroundColor: Colors.grey[200],
                                color: Colors.orange, minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${userBook.currentPage}/${userBook.book.pageCount}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                    if (userBook.status == ReadingStatus.read &&
                        userBook.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < userBook.rating!.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 14, color: Colors.amber,
                        )),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover() => Container(
    width: 52, height: 78,
    decoration: BoxDecoration(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.book, color: Colors.deepPurple, size: 26),
  );
}