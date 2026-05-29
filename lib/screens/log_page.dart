// lib/screens/log_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../services/log_service.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
        () => setState(() => _query = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _userId =>
      Provider.of<AuthService>(context, listen: false).user!.uid;

  @override
  Widget build(BuildContext context) {
    final ls = LogService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivite Geçmişi'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        toolbarHeight: 48,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Log ara...',
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.deepPurple, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ActivityLog>>(
              stream: ls.watchLogs(_userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.deepPurple));
                }

                var logs = snapshot.data ?? [];

                if (_query.isNotEmpty) {
                  logs = logs
                      .where((l) =>
                          l.description.toLowerCase().contains(_query) ||
                          ActivityLog.meta(l.type).$2.toLowerCase().contains(_query))
                      .toList();
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 72, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            _query.isNotEmpty
                                ? '"$_query" için sonuç bulunamadı'
                                : 'Henüz aktivite yok',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final grouped = _groupByDate(logs);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: grouped.length,
                  itemBuilder: (context, i) {
                    final entry = grouped[i];
                    if (entry is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                        child: Text(
                          entry,
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 0.5),
                        ),
                      );
                    }
                    return _LogTile(log: entry as ActivityLog);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _groupByDate(List<ActivityLog> logs) {
    final result = <dynamic>[];
    String? lastDate;
    for (final log in logs) {
      final dateStr = _formatDate(log.createdAt);
      if (dateStr != lastDate) {
        result.add(dateStr);
        lastDate = dateStr;
      }
      result.add(log);
    }
    return result;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDay = DateTime(dt.year, dt.month, dt.day);
    if (logDay == today) return 'BUGÜN';
    if (logDay == yesterday) return 'DÜN';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final (emoji, category) = ActivityLog.meta(log.type);

    final color = switch (category) {
      'Kütüphane' => Colors.blue,
      'Hedefler' => Colors.orange,
      'Takas' => Colors.green,
      'Sohbet' => Colors.purple,
      _ => Colors.grey,
    };

    final timeStr =
        '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Sabit genişlik: ikon + kategori ─────────────────────
          SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8,
                        color: color,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // ── Dikey ayırıcı ────────────────────────────────────────
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          // ── Açıklama ─────────────────────────────────────────────
          Expanded(
            child: Text(
              log.description,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 6),
          // ── Saat ─────────────────────────────────────────────────
          Text(
            timeStr,
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}