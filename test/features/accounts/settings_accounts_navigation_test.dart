import 'package:finote/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('settings opens account management', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/accounts',
          builder: (_, _) => const Scaffold(body: Text('Account management')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akun & Dompet'));
    await tester.pumpAndSettle();

    expect(find.text('Account management'), findsOneWidget);
  });
}
