import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell scaffold that houses the bottom navigation bar and a centered FAB.
///
/// Each tab keeps its own navigation state via [StatefulShellRoute].
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final showAddButton =navigationShell.currentIndex == 0 || navigationShell.currentIndex == 1;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: showAddButton
      ? FloatingActionButton(
          onPressed: () => _showAddMenu(context),
          tooltip: 'Tambah transaksi',
          child: const Icon(Icons.add),
        )
      : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Tambah transaksi manual'),
                subtitle: const Text('Cara utama yang cepat dan andal'),
                onTap: () => Navigator.pop(context, '/transactions/new'),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scan struk'),
                subtitle: const Text('Ambil atau pilih foto struk'),
                onTap: () => Navigator.pop(context, '/receipt-scan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (route != null && context.mounted) context.push(route);
  }
}
