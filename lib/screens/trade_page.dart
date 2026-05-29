// lib/screens/trade_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../services/trade_service.dart';
import '../services/firestore_service.dart';
import '../models/user_book_model.dart';
import '../models/book_model.dart';
import 'trade_search_page.dart';
import 'trade_chat_page.dart';
import '../data/turkey_locations.dart';

class TradePage extends StatefulWidget {
  const TradePage({super.key});

  @override
  State<TradePage> createState() => _TradePageState();
}

class _TradePageState extends State<TradePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TradeService _ts = TradeService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Arka planda eski reddedilen teklifleri temizle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ts.cleanOldRejectedRequests(_userId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _userId =>
      Provider.of<AuthService>(context, listen: false).user!.uid;

  String get _displayName {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.displayName?.isNotEmpty == true
        ? auth.displayName!
        : auth.user?.email?.split('@').first ?? 'Kullanıcı';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Üst kısım — mor arka plan
          Material(
            color: Colors.deepPurple,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Arama çubuğu — sol ikonu + tıklanabilir metin
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TradeSearchPage(
                        currentUserId: _userId,
                        currentUserDisplayName: _displayName,
                      ),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Takas edilecek kitap ara...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // TabBar — ikon ve yazı yan yana
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.white,
                  tabs: [
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, size: 16),
                          SizedBox(width: 4),
                          Text('Kitaplar', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Tab(
                      child: _BadgeTab(
                        icon: Icons.inbox,
                        label: 'Teklifler',
                        stream: _ts.watchIncomingRequestCount(_userId),
                      ),
                    ),
                    Tab(
                      child: _BadgeTab(
                        icon: Icons.chat_bubble_outline,
                        label: 'Sohbetler',
                        stream: _ts.watchChatCount(_userId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // İçerik
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MyListingsTab(userId: _userId, displayName: _displayName),
                _RequestsTab(userId: _userId, displayName: _displayName),
                _ChatsTab(userId: _userId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge'li tab ──────────────────────────────────────────────────────────────

class _BadgeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<int> stream;

  const _BadgeTab({
    required this.icon,
    required this.label,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Takaslarım sekmesi ────────────────────────────────────────────────────────

class _MyListingsTab extends StatelessWidget {
  final String userId;
  final String displayName;
  const _MyListingsTab({required this.userId, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final ts = TradeService();

    return StreamBuilder<List<TradeListing>>(
      stream: ts.watchMyListings(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple));
        }
        final listings = snapshot.data ?? [];

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.deepPurple.withOpacity(0.06),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Merhaba, $displayName 👋',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          listings.isEmpty
                              ? 'Henüz takasa kitap eklemedin'
                              : '${listings.length} kitabın takasta',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showAddListingSheet(context, userId, displayName),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Kitap Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            if (listings.isEmpty)
              Expanded(child: _emptyListings())
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: listings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ListingCard(
                    listing: listings[i],
                    onRemove: () async {
                      await ts.removeListing(
                        listings[i].id,
                        userId: userId,
                        bookTitle: listings[i].title,
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyListings() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Takasa kitap eklemedin',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Kütüphanendeki kitapları takas için ekleyebilirsin',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showAddListingSheet(
      BuildContext context, String userId, String displayName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _AddListingSheet(userId: userId, displayName: displayName),
    );
  }
}

// ── Listing kartı ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final TradeListing listing;
  final VoidCallback onRemove;
  const _ListingCard({required this.listing, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: listing.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: listing.coverUrl!,
                      width: 48, height: 72, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _cover())
                  : _cover(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(listing.author,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on,
                        size: 12, color: Colors.deepPurple),
                    const SizedBox(width: 3),
                    Text('${listing.city} / ${listing.district}',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Takastan Kaldır'),
                    content: Text(
                        '"${listing.title}" kitabını takas listesinden kaldırmak istiyor musun?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Vazgeç')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Kaldır')),
                    ],
                  ),
                );
                if (confirm == true) onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() => Container(
        width: 48,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.book, color: Colors.deepPurple, size: 24),
      );
}

// ── Listing ekleme sheet ──────────────────────────────────────────────────────

class _AddListingSheet extends StatefulWidget {
  final String userId;
  final String displayName;
  const _AddListingSheet(
      {required this.userId, required this.displayName});

  @override
  State<_AddListingSheet> createState() => _AddListingSheetState();
}

class _AddListingSheetState extends State<_AddListingSheet> {
  final TradeService _ts = TradeService();
  final FirestoreService _fs = FirestoreService();

  List<UserBookModel> _myBooks = [];
  UserBookModel? _selectedBook;
  String? _selectedCity;
  String? _selectedDistrict;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Kaydedilmiş konum tercihini yükle
    final auth = Provider.of<AuthService>(context, listen: false);
    _selectedCity = auth.preferredCity;
    _selectedDistrict = auth.preferredDistrict;
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final readSnap =
        await _fs.watchBooksByStatus(widget.userId, ReadingStatus.read).first;
    final readingSnap =
        await _fs.watchBooksByStatus(widget.userId, ReadingStatus.reading).first;
    setState(() {
      _myBooks = [...readSnap, ...readingSnap];
      _loading = false;
    });
  }

  Future<String?> _pickLocation(
      List<String> items, String title, String? selected) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SearchableLocationSheet(
          items: items, title: title, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('Takasa Kitap Ekle',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Kitap Seç',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_myBooks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                    'Kütüphanende "Okudum" veya "Okuyorum" statüsünde kitap yok.',
                    style: TextStyle(color: Colors.orange)),
              )
            else
              GestureDetector(
                onTap: () async {
                  final result = await showModalBottomSheet<UserBookModel>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => _SearchableBookSheet(
                        books: _myBooks, selected: _selectedBook),
                  );
                  if (result != null) setState(() => _selectedBook = result);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          color: Colors.deepPurple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedBook != null
                              ? '${_selectedBook!.book.title} — ${_selectedBook!.book.author}'
                              : 'Kitap seçin',
                          style: TextStyle(
                            color: _selectedBook != null
                                ? Colors.black87
                                : Colors.grey[400],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Şehir',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _LocationPickerTile(
              label: _selectedCity ?? 'Şehir seçin',
              icon: Icons.location_city,
              onTap: () async {
                final r = await _pickLocation(
                    turkeyProvinces, 'Şehir seçin', _selectedCity);
                if (r != null)
                  setState(() {
                    _selectedCity = r;
                    _selectedDistrict = null;
                  });
              },
            ),
            const SizedBox(height: 12),
            const Text('İlçe',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _LocationPickerTile(
              label: _selectedDistrict ??
                  (_selectedCity == null ? 'Önce şehir seçin' : 'İlçe seçin'),
              icon: Icons.location_on,
              enabled: _selectedCity != null,
              onTap: _selectedCity == null
                  ? null
                  : () async {
                      final r = await _pickLocation(
                          districtsOf(_selectedCity!),
                          'İlçe seçin',
                          _selectedDistrict);
                      if (r != null) setState(() => _selectedDistrict = r);
                    },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: (_saving ||
                        _selectedBook == null ||
                        _selectedCity == null ||
                        _selectedDistrict == null)
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await _ts.addListing(
                          userId: widget.userId,
                          userDisplayName: widget.displayName,
                          bookId: _selectedBook!.id,
                          title: _selectedBook!.book.title,
                          author: _selectedBook!.book.author,
                          coverUrl: _selectedBook!.book.coverUrl,
                          pageCount: _selectedBook!.book.pageCount,
                          city: _selectedCity!,
                          district: _selectedDistrict!,
                        );
                        if (mounted) Navigator.pop(context);
                      },
                child: _saving
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Takasa Ekle',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Aranabilir kitap seçici sheet ─────────────────────────────────────────────

class _SearchableBookSheet extends StatefulWidget {
  final List<UserBookModel> books;
  final UserBookModel? selected;

  const _SearchableBookSheet({required this.books, this.selected});

  @override
  State<_SearchableBookSheet> createState() => _SearchableBookSheetState();
}

class _SearchableBookSheetState extends State<_SearchableBookSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<UserBookModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    // Alfabetik sırala
    _filtered = List.from(widget.books)
      ..sort((a, b) =>
          a.book.title.toLowerCase().compareTo(b.book.title.toLowerCase()));
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = widget.books
            .where((b) =>
                b.book.title.toLowerCase().contains(q) ||
                b.book.author.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) =>
              a.book.title.toLowerCase().compareTo(b.book.title.toLowerCase()));
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Kitap veya yazar ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final book = _filtered[i];
                final isSelected = book.id == widget.selected?.id;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: book.book.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: book.book.coverUrl!,
                            width: 36, height: 50, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  title: Text(book.book.title,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(book.book.author,
                      style: const TextStyle(fontSize: 11)),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.deepPurple)
                      : null,
                  selected: isSelected,
                  selectedColor: Colors.deepPurple,
                  onTap: () => Navigator.pop(context, book),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 36, height: 50,
    decoration: BoxDecoration(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Icon(Icons.book, color: Colors.deepPurple, size: 18),
  );
}

// ── Konum seçici tile ─────────────────────────────────────────────────────────

class _LocationPickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _LocationPickerTile({
    required this.label,
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(
              color: enabled ? Colors.grey[300]! : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(10),
          color: enabled ? Colors.white : Colors.grey[50],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon,
                color: enabled ? Colors.deepPurple : Colors.grey[400],
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: enabled ? Colors.black87 : Colors.grey[400],
                    fontSize: 14),
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: enabled ? Colors.grey : Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// ── Aranabilir konum sheet ────────────────────────────────────────────────────

class _SearchableLocationSheet extends StatefulWidget {
  final List<String> items;
  final String title;
  final String? selected;

  const _SearchableLocationSheet(
      {required this.items, required this.title, this.selected});

  @override
  State<_SearchableLocationSheet> createState() =>
      _SearchableLocationSheetState();
}

class _SearchableLocationSheetState
    extends State<_SearchableLocationSheet> {
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
            : widget.items
                .where((i) => i.toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                final selected = item == widget.selected;
                return ListTile(
                  title: Text(item),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.deepPurple)
                      : null,
                  selected: selected,
                  selectedColor: Colors.deepPurple,
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

// ── Teklifler sekmesi (Gelen / Gönderilen) ────────────────────────────────────

class _RequestsTab extends StatefulWidget {
  final String userId;
  final String displayName;
  const _RequestsTab({required this.userId, required this.displayName});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.deepPurple.withOpacity(0.06),
          child: TabBar(
            controller: _subTabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(text: 'Gelen Teklifler'),
              Tab(text: 'Gönderilen Teklifler'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _IncomingRequestsList(
                  userId: widget.userId, displayName: widget.displayName),
              _OutgoingRequestsList(userId: widget.userId),
            ],
          ),
        ),
      ],
    );
  }
}

// Gelen teklifler listesi
class _IncomingRequestsList extends StatelessWidget {
  final String userId;
  final String displayName;
  const _IncomingRequestsList(
      {required this.userId, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final ts = TradeService();
    return StreamBuilder<List<TradeRequest>>(
      stream: ts.watchIncomingRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return _emptyState('Bekleyen gelen teklif yok', Icons.inbox);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _IncomingRequestCard(
            request: requests[i],
            myDisplayName: displayName,
            onAccept: () async {
              await ts.acceptRequest(
                  request: requests[i], myDisplayName: displayName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Teklif kabul edildi! Sohbet oluşturuldu.'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            onReject: () async => await ts.rejectRequest(
              requests[i].id,
              userId: userId,
              fromUser: requests[i].fromUserDisplayName,
              bookTitle: requests[i].targetBookTitle,
              fromUserId: requests[i].fromUserId,
              myDisplayName: displayName,
            ),
          ),
        );
      },
    );
  }
}

// Gönderilen teklifler listesi
class _OutgoingRequestsList extends StatelessWidget {
  final String userId;
  const _OutgoingRequestsList({required this.userId});

  @override
  Widget build(BuildContext context) {
    final ts = TradeService();
    return StreamBuilder<List<TradeRequest>>(
      stream: ts.watchOutgoingRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return _emptyState('Gönderilen teklif yok', Icons.send_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _OutgoingRequestCard(request: requests[i]),
        );
      },
    );
  }
}

Widget _emptyState(String text, IconData icon) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: Colors.grey[500])),
        ],
      ),
    ),
  );
}

// Gelen teklif kartı (kabul/reddet)
class _IncomingRequestCard extends StatelessWidget {
  final TradeRequest request;
  final String myDisplayName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingRequestCard({
    required this.request, required this.myDisplayName,
    required this.onAccept, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Text(request.fromUserDisplayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                _StatusBadge(status: request.status),
              ],
            ),
            const Divider(height: 16),
            _RequestRow(Icons.arrow_forward, Colors.green,
                'İstediği: ', request.targetBookTitle),
            const SizedBox(height: 4),
            _RequestRow(Icons.arrow_back, Colors.blue, 'Verecekleri: ',
                request.offeredBooks.map((b) => b['title'] ?? '').join(', ')),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Gönderilen teklif kartı (sadece durum göster)
class _OutgoingRequestCard extends StatelessWidget {
  final TradeRequest request;
  const _OutgoingRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.send, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      request.toUserDisplayName.isNotEmpty
                          ? '${request.toUserDisplayName} kullanıcısına'
                          : '${request.toUserId.substring(0, 6)}... kullanıcısına',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                _StatusBadge(status: request.status),
              ],
            ),
            const Divider(height: 16),
            _RequestRow(Icons.arrow_forward, Colors.green,
                'İstenen kitap: ', request.targetBookTitle),
            const SizedBox(height: 4),
            _RequestRow(Icons.arrow_back, Colors.blue, 'Teklif ettiğin: ',
                request.offeredBooks.map((b) => b['title'] ?? '').join(', ')),
            const SizedBox(height: 8),
            Text(
              'Gönderildi: ${_formatDate(request.createdAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Bekliyor', Colors.orange),
      'accepted' => ('Kabul Edildi', Colors.green),
      'rejected' => ('Reddedildi', Colors.red),
      _ => ('Bilinmiyor', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RequestRow(this.icon, this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis, maxLines: 2),
        ),
      ],
    );
  }
}

// ── Sohbetler sekmesi ─────────────────────────────────────────────────────────

class _ChatsTab extends StatelessWidget {
  final String userId;
  const _ChatsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final ts = TradeService();

    return StreamBuilder<List<TradeChat>>(
      stream: ts.watchChats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple));
        }
        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Henüz sohbet yok',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text(
                      'Bir takas teklifi kabul edildiğinde\nsohbet burada açılır',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final chat = chats[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              tileColor: Colors.white,
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.withOpacity(0.15),
                child: Text(
                  chat.otherUserDisplayName.isNotEmpty
                      ? chat.otherUserDisplayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(chat.otherUserDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                chat.lastMessage ?? 'Sohbet başladı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              trailing: chat.lastMessageAt != null
                  ? Text(
                      '${chat.lastMessageAt!.day.toString().padLeft(2, '0')}.${chat.lastMessageAt!.month.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400]),
                    )
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TradeChatPage(
                    chat: chat,
                    currentUserId: userId,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}