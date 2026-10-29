import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// NavigationBar 5 tab (docs/UI-KuotaPlus.md, Navigasi). Urutan harus sama dengan branch di router.dart.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Ketuk tab yang sedang aktif = kembali ke layar awal tab itu.
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Paket'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Analisis'),
          NavigationDestination(icon: Icon(Icons.stars_outlined), selectedIcon: Icon(Icons.stars), label: 'Reward'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Riwayat'),
        ],
      ),
    );
  }
}
