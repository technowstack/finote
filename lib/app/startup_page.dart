import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('Catatan Keuangan'),
              const SizedBox(height: 8),
              const Text('Fondasi aplikasi siap.'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/transactions'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Buka transaksi'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/categories'),
                icon: const Icon(Icons.category_outlined),
                label: const Text('Kelola kategori'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
