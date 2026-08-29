import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/categories/presentation/category_page.dart';
import 'startup_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StartupPage()),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
