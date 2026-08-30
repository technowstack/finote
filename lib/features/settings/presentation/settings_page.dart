import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';

/// Settings hub page that links to Categories, Backup, Legacy Import,
/// and Security screens.
///
/// Keeps the dashboard clean by moving these items out of its popup menu.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.sm,
        ),
        children: [
          _SettingsGroup(
            title: 'Data',
            children: [
              _SettingsTile(
                icon: Icons.category_outlined,
                title: 'Kategori',
                subtitle: 'Kelola kategori pemasukan dan pengeluaran',
                onTap: () => context.push('/categories'),
              ),
              _SettingsTile(
                icon: Icons.backup_outlined,
                title: 'Backup dan restore',
                subtitle: 'Cadangkan atau pulihkan data',
                onTap: () => context.push('/backup'),
              ),
              _SettingsTile(
                icon: Icons.move_to_inbox_outlined,
                title: 'Import aplikasi lama',
                subtitle: 'Migrasi data dari versi sebelumnya',
                onTap: () => context.push('/legacy-import'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsGroup(
            title: 'Keamanan',
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Kunci aplikasi',
                subtitle: 'PIN dan autentikasi biometrik',
                onTap: () => context.push('/security'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsGroup(
            title: 'Tentang',
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Catatan Keuangan',
                subtitle: 'Versi 1.0.0',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
