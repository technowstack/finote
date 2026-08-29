import 'package:flutter/material.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 48),
              SizedBox(height: 16),
              Text('Catatan Keuangan'),
              SizedBox(height: 8),
              Text('Fondasi aplikasi siap.'),
            ],
          ),
        ),
      ),
    );
  }
}
