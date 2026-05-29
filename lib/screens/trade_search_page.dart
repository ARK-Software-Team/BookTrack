// lib/screens/trade_search_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/trade_service.dart';
import '../data/turkey_locations.dart';

class TradeSearchPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserDisplayName;

  const TradeSearchPage({
    super.key,
    required this.currentUserId,
    required this.currentUserDisplayName,
  });

  @override
  State<TradeSearchPage> createState() => _TradeSearchPageState();
}

class _TradeSearchPageState extends State<TradeSearchPage> {
  final TradeService _ts = TradeService();
  final TextEditingController _queryController = TextEditingController();

  String? _selectedCity;
  String? _selectedDistrict;
  List<TradeListing> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search() async {
    if (_selectedCity == null) return;
    setState(() { _loading = true; _searched = true; });
    final results = await _ts.searchListings(
      city: _selectedCity!,
      district: _selectedDistrict, // null olabilir → tüm şehir
      excludeUserId: widget.currentUserId,
      query: _queryController.text.trim().isEmpty ? null : _queryController.text.trim(),
    );
    setState(() { _results = results; _loading = false; });
  }

  Future<String?> _pickLocation(List<String> items, String title, String? selected) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SearchableLocationSheet(
          items: items, title: title, selected: selected),
    );
  }

  void _showOfferSheet(TradeListing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SendOfferSheet(
        listing: listing,
        currentUserId: widget.currentUserId,
        currentUserDisplayName: widget.currentUserDisplayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takas Kitabı Ara'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        toolbarHeight: 48,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.deepPurple.withOpacity(0.04),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Şehir (zorunlu)
                _LocationTile(
                  label: _selectedCity ?? 'Şehir seçin *',
                  icon: Icons.location_city,
                  hasValue: _selectedCity != null,
                  onTap: () async {
                    final r = await _pickLocation(
                        turkeyProvinces, 'Şehir seçin', _selectedCity);
                    if (r != null) {
                      setState(() {
                        _selectedCity = r;
                        _selectedDistrict = null;
                        _results = [];
                        _searched = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                // İlçe (isteğe bağlı)
                _LocationTile(
                  label: _selectedDistrict ??
                      (_selectedCity == null
                          ? 'Önce şehir seçin'
                          : 'İlçe seçin (isteğe bağlı)'),
                  icon: Icons.location_on,
                  hasValue: _selectedDistrict != null,
                  enabled: _selectedCity != null,
                  onTap: _selectedCity == null
                      ? null
                      : () async {
                          final r = await _pickLocation(
                              districtsOf(_selectedCity!),
                              'İlçe seçin',
                              _selectedDistrict);
                          if (r != null) {
                            setState(() {
                              _selectedDistrict = r;
                              _results = [];
                              _searched = false;
                            });
                          }
                        },
                ),
                if (_selectedDistrict != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _selectedDistrict = null;
                        _results = [];
                        _searched = false;
                      }),
                      child: const Text('İlçeyi temizle',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Kitap/yazar arama
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'Kitap adı veya yazar (isteğe bağlı)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _queryController.clear();
                              setState(() {});
                            })
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _selectedCity == null ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _selectedDistrict != null
                          ? 'Ara (${_selectedCity!} / $_selectedDistrict)'
                          : _selectedCity != null
                              ? 'Ara (Tüm $_selectedCity)'
                              : 'Önce şehir seçin',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }
    if (!_searched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Şehir seçip ara',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 4),
            Text('İlçe seçmek isteğe bağlı',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _selectedDistrict != null
                  ? '$_selectedCity / $_selectedDistrict bölgesinde kitap bulunamadı'
                  : '$_selectedCity genelinde takaslık kitap bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (_selectedDistrict != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _selectedDistrict = null;
                  _search();
                }),
                child: const Text('Tüm şehirde ara'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _SearchResultCard(
        listing: _results[i],
        onOffer: () => _showOfferSheet(_results[i]),
      ),
    );
  }
}

// ── Konum tile ────────────────────────────────────────────────────────────────

class _LocationTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool hasValue;
  final bool enabled;
  final VoidCallback? onTap;

  const _LocationTile({
    required this.label, required this.icon,
    this.hasValue = false, this.enabled = true, this.onTap,
  });

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
            Icon(icon,
                color: hasValue ? Colors.deepPurple : (enabled ? Colors.grey[500] : Colors.grey[300]),
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasValue ? Colors.black87 : Colors.grey[400],
                  fontSize: 14,
                ),
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

class _SearchableLocationSheetState extends State<_SearchableLocationSheet> {
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
            decoration: BoxDecoration(color: Colors.grey[300],
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

// ── Sonuç kartı ───────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final TradeListing listing;
  final VoidCallback onOffer;

  const _SearchResultCard({required this.listing, required this.onOffer});

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
              borderRadius: BorderRadius.circular(6),
              child: listing.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: listing.coverUrl!,
                      width: 56, height: 82, fit: BoxFit.cover,
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
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(listing.author,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  if (listing.pageCount != null) ...[
                    const SizedBox(height: 3),
                    Text('${listing.pageCount} sayfa',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 12, color: Colors.deepPurple),
                    const SizedBox(width: 3),
                    Text(listing.userDisplayName,
                        style: const TextStyle(fontSize: 11,
                            color: Colors.deepPurple, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text('${listing.city} / ${listing.district}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Teklif Et', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() => Container(
    width: 56, height: 82,
    decoration: BoxDecoration(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.book, color: Colors.deepPurple, size: 28),
  );
}

// ── Teklif gönder sheet ───────────────────────────────────────────────────────

class _SendOfferSheet extends StatefulWidget {
  final TradeListing listing;
  final String currentUserId;
  final String currentUserDisplayName;

  const _SendOfferSheet({
    required this.listing,
    required this.currentUserId,
    required this.currentUserDisplayName,
  });

  @override
  State<_SendOfferSheet> createState() => _SendOfferSheetState();
}

class _SendOfferSheetState extends State<_SendOfferSheet> {
  final TradeService _ts = TradeService();
  List<TradeListing> _myListings = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    final listings = await _ts.watchMyListings(widget.currentUserId).first;
    setState(() { _myListings = listings; _loading = false; });
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
            const Text('Takas Teklifi Gönder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.deepPurple, size: 16),
                  const SizedBox(width: 6),
                  const Text('İstediğin: ',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Text(widget.listing.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Karşılığında ne vermek istiyorsun?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Text('Kendi takas listendeki kitaplardan seç',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_myListings.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                    'Takas listende hiç kitap yok. Önce "Takaslarım" sekmesinden kitap ekle.',
                    style: TextStyle(color: Colors.orange)),
              )
            else
              ...(_myListings.map((l) {
                final selected = _selectedIds.contains(l.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (v) => setState(() {
                    v == true ? _selectedIds.add(l.id) : _selectedIds.remove(l.id);
                  }),
                  title: Text(l.title,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(l.author, style: const TextStyle(fontSize: 11)),
                  activeColor: Colors.deepPurple,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              })),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_sending || _selectedIds.isEmpty) ? null : () async {
                  setState(() => _sending = true);
                  final offeredBooks = _myListings
                      .where((l) => _selectedIds.contains(l.id))
                      .map((l) => {'listingId': l.id, 'title': l.title, 'author': l.author})
                      .toList();
                  try {
                    await _ts.sendTradeRequest(
                      fromUserId: widget.currentUserId,
                      fromUserDisplayName: widget.currentUserDisplayName,
                      toUserId: widget.listing.userId,
                      toUserDisplayName: widget.listing.userDisplayName,
                      targetListingId: widget.listing.id,
                      targetBookTitle: widget.listing.title,
                      offeredBooks: offeredBooks,
                    );
                  } catch (_) {
                    if (mounted) setState(() => _sending = false);
                    return;
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Teklif gönderildi!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: _sending
                    ? const SizedBox(height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_selectedIds.isEmpty
                        ? 'En az 1 kitap seç'
                        : 'Teklif Gönder (${_selectedIds.length} kitap)',
                        style: const TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}