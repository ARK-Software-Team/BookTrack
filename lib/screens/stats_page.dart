// lib/screens/stats_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';
import '../services/log_service.dart';

// Grafik zaman dilimi
enum ChartPeriod { weekly, monthly, yearly }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _loading = true;
  int _totalBooks = 0;
  int _booksRead = 0;
  int _currentlyReading = 0;
  int _wantToRead = 0;
  int _totalPages = 0;
  int _tradeBooksReceived = 0;
  int _tradeBooksGiven = 0;

  // Veri haritaları — tüm dönemler için tutuyoruz
  // Kitap: key = gün offseti(haftalık), ay(aylık), ay(yıllık)
  Map<int, int> _weeklyBooks = {};   // 0-6: Pzt-Paz
  Map<int, int> _monthlyBooks = {};  // 1-31: günler
  Map<int, int> _yearlyBooks = {};   // 1-12: aylar

  Map<int, int> _weeklyTrades = {};
  Map<int, int> _monthlyTrades = {};
  Map<int, int> _yearlyTrades = {};

  List<Map<String, dynamic>> _recentlyRead = []; // son 1 ay

  ChartPeriod _selectedPeriod = ChartPeriod.yearly;

  String get _userId =>
      Provider.of<AuthService>(context, listen: false).user!.uid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    final snap = await db
        .collection('users').doc(_userId).collection('userBooks').get();

    int totalBooks = snap.docs.length;
    int booksRead = 0, currentlyReading = 0, wantToRead = 0, totalPages = 0;
    final weeklyB = <int, int>{};
    final monthlyB = <int, int>{};
    final yearlyB = <int, int>{};
    final recentlyRead = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final bookData = data['book'] as Map<String, dynamic>?;
      final pageCount = (bookData?['pageCount'] as int?) ?? 0;
      final currentPage = (data['currentPage'] as int?) ?? 0;
      final finishedTs = data['finishedAt'] as Timestamp?;
      final addedTs = data['addedAt'] as Timestamp?;
      final effectiveDate = (finishedTs ?? addedTs)?.toDate();

      switch (status) {
        case 'read':
          booksRead++;
          totalPages += pageCount;
          if (effectiveDate != null) {
            // Yıllık
            if (!effectiveDate.isBefore(yearStart)) {
              yearlyB[effectiveDate.month] = (yearlyB[effectiveDate.month] ?? 0) + 1;
            }
            // Aylık (bu ay)
            if (!effectiveDate.isBefore(monthStart)) {
              monthlyB[effectiveDate.day] = (monthlyB[effectiveDate.day] ?? 0) + 1;
            }
            // Haftalık (bu hafta)
            final eDay = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);
            if (!eDay.isBefore(weekStartDay)) {
              final offset = eDay.difference(weekStartDay).inDays; // 0-6
              if (offset < 7) weeklyB[offset] = (weeklyB[offset] ?? 0) + 1;
            }
            // Son 1 ay için recently read
            if (effectiveDate.isAfter(oneMonthAgo) && bookData != null) {
              recentlyRead.add({
                'title': bookData['title'] ?? '',
                'author': bookData['author'] ?? '',
                'coverUrl': bookData['coverUrl'],
                'rating': data['rating'],
                'finishedAt': effectiveDate,
                'pageCount': pageCount,
              });
            }
          }
          break;
        case 'reading':
          currentlyReading++;
          totalPages += currentPage;
          break;
        case 'wantToRead':
          wantToRead++;
          break;
      }
    }

    recentlyRead.sort((a, b) {
      final aDate = a['finishedAt'] as DateTime?;
      final bDate = b['finishedAt'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    // Takas verileri — tradeListings'den
    final tradeSnap = await db
        .collection('tradeListings')
        .where('userId', isEqualTo: _userId)
        .get();

    final weeklyT = <int, int>{};
    final monthlyT = <int, int>{};
    final yearlyT = <int, int>{};

    for (final doc in tradeSnap.docs) {
      final data = doc.data();
      final createdTs = data['createdAt'] as Timestamp?;
      if (createdTs == null) continue;
      final date = createdTs.toDate();
      // Yıllık
      if (date.year == now.year) {
        yearlyT[date.month] = (yearlyT[date.month] ?? 0) + 1;
      }
      // Aylık (bu ay)
      if (date.year == now.year && date.month == now.month) {
        monthlyT[date.day] = (monthlyT[date.day] ?? 0) + 1;
      }
      // Haftalık
      final dDay = DateTime(date.year, date.month, date.day);
      if (!dDay.isBefore(weekStartDay)) {
        final offset = dDay.difference(weekStartDay).inDays;
        if (offset < 7) weeklyT[offset] = (weeklyT[offset] ?? 0) + 1;
      }
    }

    final tradeStats = await LogService().getTradeStats(_userId);

    setState(() {
      _totalBooks = totalBooks;
      _booksRead = booksRead;
      _currentlyReading = currentlyReading;
      _wantToRead = wantToRead;
      _totalPages = totalPages;
      _weeklyBooks = weeklyB;
      _monthlyBooks = monthlyB;
      _yearlyBooks = yearlyB;
      _weeklyTrades = weeklyT;
      _monthlyTrades = monthlyT;
      _yearlyTrades = yearlyT;
      _tradeBooksReceived = tradeStats['received'] ?? 0;
      _tradeBooksGiven = tradeStats['given'] ?? 0;
      _recentlyRead = recentlyRead;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.deepPurple,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 12),
                  _buildPeriodSelector(),
                  const SizedBox(height: 12),
                  _buildBookChart(),
                  const SizedBox(height: 12),
                  _buildTradeChart(),
                  const SizedBox(height: 12),
                  _buildRecentlyRead(),
                ],
              ),
            ),
    );
  }

  // ── Özet kartlar ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.deepPurple, Color(0xFF7B1FA2)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(child: _bigStat('Toplam Kitap', '$_totalBooks')),
              Expanded(child: _bigStat('Okunan Sayfa', '$_totalPages')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _miniCard('Okudum', '$_booksRead', Icons.check_circle_outline, Colors.green),
            const SizedBox(width: 10),
            _miniCard('Okuyorum', '$_currentlyReading', Icons.menu_book, Colors.orange),
            const SizedBox(width: 10),
            _miniCard('Okunacak', '$_wantToRead', Icons.bookmark_outline, Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _miniCard('Takasla Alınan', '$_tradeBooksReceived', Icons.arrow_downward, Colors.teal),
            const SizedBox(width: 10),
            _miniCard('Takasla Verilen', '$_tradeBooksGiven', Icons.arrow_upward, Colors.deepPurple),
          ],
        ),
      ],
    );
  }

  Widget _bigStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _miniCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ),
    );
  }

  // ── Dönem seçici ──────────────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    return Row(
      children: ChartPeriod.values.map((p) {
        final selected = _selectedPeriod == p;
        final label = switch (p) {
          ChartPeriod.weekly => 'Haftalık',
          ChartPeriod.monthly => 'Aylık',
          ChartPeriod.yearly => 'Yıllık',
        };
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPeriod = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.deepPurple : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? Colors.deepPurple : Colors.grey[300]!),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.deepPurple.withOpacity(0.25),
                        blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Okunan kitap grafiği ──────────────────────────────────────────────────

  Widget _buildBookChart() {
    final data = switch (_selectedPeriod) {
      ChartPeriod.weekly => _weeklyBooks,
      ChartPeriod.monthly => _monthlyBooks,
      ChartPeriod.yearly => _yearlyBooks,
    };
    return _buildChart(
      title: 'Okunan Kitap',
      data: data,
      color: Colors.deepPurple,
    );
  }

  // ── Yapılan takas grafiği ─────────────────────────────────────────────────

  Widget _buildTradeChart() {
    final data = switch (_selectedPeriod) {
      ChartPeriod.weekly => _weeklyTrades,
      ChartPeriod.monthly => _monthlyTrades,
      ChartPeriod.yearly => _yearlyTrades,
    };
    return _buildChart(
      title: 'Yapılan Takas',
      data: data,
      color: Colors.teal,
    );
  }

  Widget _buildChart({
    required String title,
    required Map<int, int> data,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_periodSubtitle(),
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: _selectedPeriod == ChartPeriod.monthly
                ? _buildLineChart(data, color)
                : _buildBarChart(data, color),
          ),
        ],
      ),
    );
  }

  String _periodSubtitle() {
    final now = DateTime.now();
    return switch (_selectedPeriod) {
      ChartPeriod.weekly => 'Bu Hafta',
      ChartPeriod.monthly => '${now.month}. Ay ${now.year}',
      ChartPeriod.yearly => '${now.year}',
    };
  }

  // ── Bar grafik (haftalık ve yıllık) ──────────────────────────────────────

  Widget _buildBarChart(Map<int, int> data, Color color) {
    final now = DateTime.now();
    final isWeekly = _selectedPeriod == ChartPeriod.weekly;
    final count = isWeekly ? 7 : 12;
    final labels = isWeekly
        ? ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
        : ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

    final maxVal = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    final currentIdx = isWeekly ? (now.weekday - 1) : (now.month - 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(count, (i) {
        final key = isWeekly ? i : (i + 1);
        final val = data[key] ?? 0;
        final barH = maxVal > 0 ? (val / maxVal) * 90.0 : 0.0;
        final isCurrent = i == currentIdx;
        final isFuture = isWeekly ? false : (i + 1) > now.month;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 14,
                  child: val > 0
                      ? Text('$val',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? color : Colors.grey[600]))
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: barH + 4,
                  decoration: BoxDecoration(
                    color: isFuture
                        ? Colors.grey[200]
                        : isCurrent
                            ? color
                            : val > 0
                                ? color.withOpacity(0.6)
                                : Colors.grey[200],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 14,
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          color: isCurrent ? color : Colors.grey[400],
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Line grafik (aylık — 30 gün) ─────────────────────────────────────────

  Widget _buildLineChart(Map<int, int> data, Color color) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal < 1 ? 1 : maxVal;

    return CustomPaint(
      painter: _LineChartPainter(
        data: data,
        daysInMonth: daysInMonth,
        currentDay: now.day,
        maxVal: effectiveMax,
        color: color,
      ),
      size: const Size(double.infinity, 140),
    );
  }

  // ── Son okuduklarım (son 1 ay) ────────────────────────────────────────────

  Widget _buildRecentlyRead() {
    if (_recentlyRead.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text('Son 1 ayda tamamlanan kitap yok',
              style: TextStyle(color: Colors.grey[400])),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Son Okuduklarım',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Son 1 ay',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 8),
        ...(_recentlyRead.map((book) => _RecentBookTile(book: book))),
      ],
    );
  }
}

// ── Line Chart Painter ────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final Map<int, int> data;
  final int daysInMonth;
  final int currentDay;
  final int maxVal;
  final Color color;

  _LineChartPainter({
    required this.data,
    required this.daysInMonth,
    required this.currentDay,
    required this.maxVal,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - 20; // bottom label space
    final stepX = size.width / (daysInMonth - 1);

    // Grid çizgileri
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartH - (i / 4) * chartH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Veri noktaları
    final points = <Offset>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final val = data[d] ?? 0;
      final x = (d - 1) * stepX;
      final y = chartH - (val / maxVal) * chartH;
      points.add(Offset(x, y));
    }

    // Dolgu alanı
    if (points.isNotEmpty) {
      final fillPath = Path()..moveTo(points.first.dx, chartH);
      for (final p in points) fillPath.lineTo(p.dx, p.dy);
      fillPath.lineTo(points.last.dx, chartH);
      fillPath.close();
      canvas.drawPath(
          fillPath,
          Paint()
            ..color = color.withOpacity(0.12)
            ..style = PaintingStyle.fill);

      // Çizgi
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);

      // Nokta — veri olan günler
      for (int d = 1; d <= daysInMonth; d++) {
        if ((data[d] ?? 0) > 0) {
          final p = points[d - 1];
          canvas.drawCircle(p, 3, Paint()..color = color);
        }
      }
    }

    // Gün etiketleri — sadece 1, 8, 15, 22, son gün
    final textStyle = TextStyle(color: Colors.grey[400], fontSize: 9);
    for (final d in [1, 8, 15, 22, daysInMonth]) {
      if (d > daysInMonth) continue;
      final x = (d - 1) * stepX;
      final tp = TextPainter(
        text: TextSpan(text: '$d', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartH + 4));
    }

    // Bugünü işaretle
    if (currentDay <= daysInMonth) {
      final cx = (currentDay - 1) * stepX;
      canvas.drawLine(
          Offset(cx, 0),
          Offset(cx, chartH),
          Paint()
            ..color = color.withOpacity(0.4)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.maxVal != maxVal;
}

// ── Son okunan kitap tile ─────────────────────────────────────────────────────

class _RecentBookTile extends StatelessWidget {
  final Map<String, dynamic> book;
  const _RecentBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final rating = (book['rating'] as num?)?.toDouble();
    final finishedAt = book['finishedAt'] as DateTime?;
    final pageCount = book['pageCount'] as int?;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: book['coverUrl'] != null
                  ? CachedNetworkImage(
                      imageUrl: book['coverUrl'],
                      width: 44, height: 64, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(book['author'] ?? '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null) ...[
                        ...List.generate(5, (i) => Icon(
                            i < rating.round() ? Icons.star : Icons.star_border,
                            size: 12, color: Colors.amber)),
                        const SizedBox(width: 8),
                      ],
                      if (pageCount != null)
                        Text('$pageCount sayfa',
                            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ),
            if (finishedAt != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(height: 4),
                  Text(
                    '${finishedAt.day.toString().padLeft(2, '0')}.${finishedAt.month.toString().padLeft(2, '0')}.${finishedAt.year}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 44, height: 64,
    decoration: BoxDecoration(
      color: Colors.deepPurple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.book, color: Colors.deepPurple, size: 20),
  );
}