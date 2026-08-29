import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/categories/presentation/category_page.dart';
import '../features/transactions/presentation/transaction_form_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import 'startup_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StartupPage()),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryPage(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const TransactionFormPage(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => TransactionFormPage(
              transactionId: int.tryParse(state.pathParameters['id'] ?? ''),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
