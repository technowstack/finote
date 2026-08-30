import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_logger.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/categories/data/category_repository.dart';
import '../features/app_lock/presentation/app_lock.dart';
import 'router.dart';

class FinoteApp extends ConsumerWidget {
  const FinoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(categoryInitializationProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) => AppLogger.error(
          'Failed to initialize default categories',
          error,
          stackTrace,
        ),
      );
    });

    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'Finote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AppLock(child: child ?? const SizedBox()),
    );
  }
}
