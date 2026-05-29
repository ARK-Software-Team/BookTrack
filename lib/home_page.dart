// lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'screens/library_page.dart';
import 'screens/search_page.dart';
import 'screens/goals_page.dart';
import 'screens/stats_page.dart';
import 'screens/trade_page.dart';
import 'screens/settings_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const _titles = ['Takas', 'Kütüphane', 'Ara', 'Hedefler', 'İstatistik'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TradePage(),
      const LibraryPage(),
      const SearchPage(),
      const GoalsPage(),
      const StatsPage(),
    ];

    return Scaffold(
      // ── Üst AppBar: sabit, tüm sayfalarda görünür ──────────────────────
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text(
              'BookTrack',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _titles[_currentIndex],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        toolbarHeight: 48, // ince AppBar
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),

      body: IndexedStack(index: _currentIndex, children: pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: Colors.deepPurple.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz, color: Colors.deepPurple),
            label: 'Takas',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library, color: Colors.deepPurple),
            label: 'Kütüphane',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: Colors.deepPurple),
            label: 'Ara',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag, color: Colors.deepPurple),
            label: 'Hedefler',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Colors.deepPurple),
            label: 'İstatistik',
          ),
        ],
      ),
    );
  }
}