import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_radius.dart';
import '../core/theme/finote_colors.dart';

final shellModalOpenProvider = StateProvider<bool>((ref) => false);

/// Bottom padding a scrollable under the shell FAB needs so its last item
/// is never covered (FAB 56 + margin 16 + shadow).
const kFabClearance = 96.0;

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
    final f = Theme.of(context).finote;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: showAddButton && !keyboardOpen && !modalOpen
          ? DecoratedBox(
              // Only the hero and the FAB carry a shadow (tokens: shadow.fab).
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: f.fabShadow,
              ),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () => _showAddMenu(context, ref),
                tooltip: 'Tambah transaksi',
                child: const Icon(Icons.add),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        child: NavigationBar(
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
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.notes_rounded),
              selectedIcon: Icon(Icons.notes_rounded),
              label: 'Transaksi',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: 'Portofolio',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Laporan',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Pengaturan',
            ),
          ],
        ),
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
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Tambah Transfer Antar Akun'),
                  subtitle: const Text(
                    'Pindahkan saldo antar akun, bukan pemasukan/pengeluaran',
                  ),
                  onTap: () => Navigator.pop(context, '/transfers'),
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
