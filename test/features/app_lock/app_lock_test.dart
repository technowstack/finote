import 'package:finote/features/app_lock/data/pin_repository.dart';
import 'package:finote/features/app_lock/presentation/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PIN hides content at startup and after app pause', (
    tester,
  ) async {
    final repository = PinRepository(_MemoryPinStore(), iterations: 2);
    await repository.setPin('1234');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AppLock(child: Scaffold(body: Text('Data pribadi'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data pribadi'), findsNothing);
    expect(find.text('Buka Catatan Keuangan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Data pribadi'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('Data pribadi'), findsNothing);
    expect(find.text('Buka Catatan Keuangan'), findsOneWidget);
  });
}

class _MemoryPinStore implements PinStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
