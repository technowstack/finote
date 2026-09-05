import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final shellModalOpenProvider = StateProvider<bool>((ref) => false);

/// Shell scaffold that houses the bottom navigation bar and the add FAB.
///
/// Each tab keeps its own navigation state via [StatefulShellRoute].
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAddButton =
        navigationShell.currentIndex == 0 || navigationShell.currentIndex == 1;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final modalOpen = ref.watch(shellModalOpenProvider);
    return Scaffold(
      body: navigationShell,
      floatingActionButton: showAddButton && !keyboardOpen && !modalOpen
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => _showAddMenu(context, ref),
              tooltip: 'Tambah transaksi',
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Portofolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
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

  Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
    if (ref.read(shellModalOpenProvider)) return;
    ref.read(shellModalOpenProvider.notifier).state = true;

    String? route;
    try {
      route = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Tambah transaksi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
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
    } finally {
      if (context.mounted) {
        ref.read(shellModalOpenProvider.notifier).state = false;
      }
    }
    if (route != null && context.mounted) context.push(route);
  }
}
