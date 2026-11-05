import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/preferences/balance_visibility_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  // Read before runApp so the first frame never flashes a masked balance.
  final balanceHidden = await readBalanceHidden();
  runApp(
    ProviderScope(
      overrides: [
        balanceHiddenProvider.overrideWith(
          () => BalanceVisibilityNotifier(balanceHidden),
        ),
      ],
      child: const FinoteApp(),
    ),
  );
}
