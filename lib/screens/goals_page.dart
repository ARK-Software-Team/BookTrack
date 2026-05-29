// lib/screens/goals_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';
import '../models/reading_goal_model.dart';
import '../services/firestore_service.dart';
import '../services/log_service.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final FirestoreService _fs = FirestoreService();
  int _refreshKey = 0;

  String get _userId =>
      Provider.of<AuthService>(context, listen: false).user!.uid;

  void _refresh() => setState(() => _refreshKey++);

  void _showGoalDialog({ReadingGoalModel? existing}) {
    GoalPeriod selectedPeriod = existing?.period ?? GoalPeriod.yearly;
    GoalType selectedType = existing?.type ?? GoalType.books;
    final countController = TextEditingController(
      text: existing != null ? '${existing.targetCount}' : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing != null ? 'Hedefi Düzenle' : 'Yeni Hedef Ekle',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text('Dönem', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: GoalPeriod.values.map((p) {
                  final selected = selectedPeriod == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => selectedPeriod = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? Colors.deepPurple : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? Colors.deepPurple : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          _periodLabel(p),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Hedef Türü', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: GoalType.values.map((t) {
                  final selected = selectedType == t;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => selectedType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? Colors.deepPurple : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? Colors.deepPurple : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              t == GoalType.books ? Icons.menu_book : Icons.format_list_numbered,
                              color: selected ? Colors.white : Colors.grey[500], size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t == GoalType.books ? 'Kitap' : 'Sayfa',
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                selectedType == GoalType.books ? 'Hedef Kitap Sayısı' : 'Hedef Sayfa Sayısı',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: selectedType == GoalType.books ? 'örn. 12' : 'örn. 5000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                  prefixIcon: Icon(
                    selectedType == GoalType.books ? Icons.menu_book : Icons.format_list_numbered,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final count = int.tryParse(countController.text.trim());
                    if (count == null || count <= 0) return;
                    Navigator.pop(ctx);
                    final now = DateTime.now();
                    final goal = ReadingGoalModel(
                      id: '', userId: _userId,
                      period: selectedPeriod, type: selectedType,
                      targetCount: count, year: now.year,
                      createdAt: existing?.createdAt ?? now, updatedAt: now,
                    );
                    await _fs.setReadingGoal(goal);

                    // Log
                    final ls = LogService();
                    final periodLbl = _periodLabel(selectedPeriod);
                    final typeLbl = selectedType == GoalType.books ? 'Kitap' : 'Sayfa';
                    await ls.addLog(
                      userId: _userId,
                      type: existing != null ? LogType.goalEdited : LogType.goalCreated,
                      description: existing != null
                          ? ls.goalEdited(periodLbl, typeLbl, count)
                          : ls.goalCreated(periodLbl, typeLbl, count),
                    );

                    _refresh();
                  },
                  child: const Text('Kaydet', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      body: StreamBuilder<List<ReadingGoalModel>>(
        stream: _fs.watchGoals(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          }
          final goals = snapshot.data ?? [];
          if (goals.isEmpty) return _buildEmptyState();

          final order = [GoalPeriod.daily, GoalPeriod.weekly, GoalPeriod.monthly, GoalPeriod.yearly];
          goals.sort((a, b) => order.indexOf(a.period).compareTo(order.indexOf(b.period)));

          return RefreshIndicator(
            color: Colors.deepPurple,
            onRefresh: () async => _refresh(),
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${DateTime.now().year} Hedefleri',
                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              ...goals.map((goal) => _GoalCard(
                    key: ValueKey('${goal.id}_$_refreshKey'),
                    goal: goal, userId: _userId,
                    onEdit: () => _showGoalDialog(existing: goal),
                    onDelete: () async {
                      await FirebaseFirestore.instance
                          .collection('users').doc(_userId)
                          .collection('readingGoals').doc(goal.id).delete();
                      // Log
                      final ls = LogService();
                      await ls.addLog(
                        userId: _userId,
                        type: LogType.goalRemoved,
                        description: ls.goalRemoved(
                          _periodLabel(goal.period),
                          goal.type == GoalType.books ? 'Kitap' : 'Sayfa',
                        ),
                      );
                    },
                  )),
            ],
          ),
          ); // RefreshIndicator
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goals_fab',
        onPressed: () => _showGoalDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Hedef Ekle'),
        backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Henüz hedef belirlemedin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Günlük, haftalık, aylık veya yıllık\nokuma hedefleri belirle',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showGoalDialog(),
              icon: const Icon(Icons.add),
              label: const Text('İlk Hedefini Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(GoalPeriod p) {
    switch (p) {
      case GoalPeriod.daily: return 'Günlük';
      case GoalPeriod.weekly: return 'Haftalık';
      case GoalPeriod.monthly: return 'Aylık';
      case GoalPeriod.yearly: return 'Yıllık';
    }
  }
}

// ── _GoalCard ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final ReadingGoalModel goal;
  final String userId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    super.key,
    required this.goal, required this.userId,
    required this.onEdit, required this.onDelete,
  });

  Future<int> _getProgress() async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();

    DateTime rangeStart;
    switch (goal.period) {
      case GoalPeriod.daily:
        rangeStart = DateTime(now.year, now.month, now.day);
        break;
      case GoalPeriod.weekly:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        rangeStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
        break;
      case GoalPeriod.monthly:
        rangeStart = DateTime(now.year, now.month, 1);
        break;
      case GoalPeriod.yearly:
        rangeStart = DateTime(now.year, 1, 1);
        break;
    }

    final snap = await db
        .collection('users').doc(userId).collection('userBooks')
        .get();

    int count = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final bookData = data['book'] as Map<String, dynamic>?;
      final pageCount = (bookData?['pageCount'] as int?) ?? 0;
      final currentPage = (data['currentPage'] as int?) ?? 0;

      if (goal.type == GoalType.books) {
        // Kitap hedefi: sadece dönem içinde tamamlanan kitapları say
        if (status != 'read') continue;
        final finishedTs = data['finishedAt'] as Timestamp?;
        final addedTs = data['addedAt'] as Timestamp?;
        final date = (finishedTs ?? addedTs)?.toDate();
        if (date == null) continue;
        if (!date.isBefore(rangeStart) && !date.isAfter(now)) {
          count++;
        }
      } else {
        // Sayfa hedefi: dönem içinde eklenen/tamamlanan kitapların sayfaları
        // "okudum" → pageCount, "okuyorum" → currentPage
        if (status == 'read') {
          final finishedTs = data['finishedAt'] as Timestamp?;
          final addedTs = data['addedAt'] as Timestamp?;
          final date = (finishedTs ?? addedTs)?.toDate();
          if (date == null) continue;
          if (!date.isBefore(rangeStart) && !date.isAfter(now)) {
            count += pageCount;
          }
        } else if (status == 'reading') {
          // Okuma seanslarından dönem içindeki sayfaları say
          final sessions = data['readingSessions'] as List<dynamic>? ?? [];
          for (final s in sessions) {
            final sMap = s as Map<String, dynamic>;
            final sDate = (sMap['date'] as Timestamp?)?.toDate();
            final pagesRead = (sMap['pagesRead'] as int?) ?? 0;
            if (sDate == null) continue;
            if (!sDate.isBefore(rangeStart) && !sDate.isAfter(now)) {
              count += pagesRead;
            }
          }
          // Session yoksa mevcut sayfayı ekle
          if (sessions.isEmpty && currentPage > 0) {
            count += currentPage;
          }
        }
      }
    }
    return count;
  }

  Color get _periodColor {
    switch (goal.period) {
      case GoalPeriod.daily: return Colors.orange;
      case GoalPeriod.weekly: return Colors.blue;
      case GoalPeriod.monthly: return Colors.green;
      case GoalPeriod.yearly: return Colors.purple;
    }
  }

  String get _periodLabel {
    switch (goal.period) {
      case GoalPeriod.daily: return 'Günlük';
      case GoalPeriod.weekly: return 'Haftalık';
      case GoalPeriod.monthly: return 'Aylık';
      case GoalPeriod.yearly: return 'Yıllık';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _periodColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_periodLabel,
                      style: TextStyle(color: _periodColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Icon(
                  goal.type == GoalType.books ? Icons.menu_book : Icons.format_list_numbered,
                  size: 16, color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(goal.type == GoalType.books ? 'Kitap' : 'Sayfa',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit, color: Colors.grey[500],
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete, color: Colors.red[300],
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<int>(
              future: _getProgress(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 40,
                    child: Center(child: LinearProgressIndicator(color: Colors.deepPurple)),
                  );
                }
                final current = snapshot.data!;
                final target = goal.targetCount;
                final progress = (current / target).clamp(0.0, 1.0);
                final done = current >= target;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          done ? '🎉 Hedefe ulaştın!' : '$current / $target',
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: done ? Colors.green : Colors.grey[800],
                          ),
                        ),
                        Text(
                          '%${(progress * 100).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: done ? Colors.green : _periodColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        color: done ? Colors.green : _periodColor,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      done
                          ? 'Tebrikler! Hedefini tamamladın.'
                          : '${target - current} ${goal.type == GoalType.books ? 'kitap' : 'sayfa'} kaldı',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}