import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/presentation/backup_page.dart';
import '../features/app_lock/presentation/security_page.dart';
import '../features/categories/presentation/category_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/legacy_import/presentation/legacy_import_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/transactions/presentation/transaction_form_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import 'main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      // ------------------------------------------------------------------
      // Bottom navigation shell
      // ------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------------------------
      // Full-screen routes (overlay bottom nav)
      // ------------------------------------------------------------------
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionFormPage(),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        redirect: (context, state) =>
            int.tryParse(state.pathParameters['id'] ?? '') == null
                ? '/transactions'
                : null,
        builder: (context, state) => TransactionFormPage(
          transactionId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryPage(),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupPage(),
      ),
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityPage(),
      ),
      GoRoute(
        path: '/legacy-import',
        builder: (context, state) => const LegacyImportPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

