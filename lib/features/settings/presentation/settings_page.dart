import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';

/// Settings hub page that links to Categories, Backup, Legacy Import,
/// Security screens, and display preferences.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _SettingsGroup(title: 'Tampilan', children: [_ThemeTile()]),
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
                title: 'Finote',
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

// ---------------------------------------------------------------------------
// Theme selector tile
// ---------------------------------------------------------------------------

class _ThemeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Tema'),
      subtitle: Text(_themeLabel(currentMode)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showThemeDialog(context, ref, currentMode),
    );
  }

  Future<void> _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => _ThemeSelectionDialog(initial: current),
    );
    if (selected != null && selected != current) {
      ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Ikuti sistem',
    ThemeMode.light => 'Terang',
    ThemeMode.dark => 'Gelap',
  };
}

class _ThemeSelectionDialog extends StatefulWidget {
  const _ThemeSelectionDialog({required this.initial});

  final ThemeMode initial;

  @override
  State<_ThemeSelectionDialog> createState() => _ThemeSelectionDialogState();
}

class _ThemeSelectionDialogState extends State<_ThemeSelectionDialog> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tema'),
      contentPadding: const EdgeInsets.only(top: AppSpacing.lg),
      content: RadioGroup<ThemeMode>(
        groupValue: _selected,
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selected = value);
          Navigator.pop(context, value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(title: Text(_label(mode)), value: mode),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Ikuti sistem',
    ThemeMode.light => 'Terang',
    ThemeMode.dark => 'Gelap',
  };
}

// ---------------------------------------------------------------------------
// Reusable settings widgets
// ---------------------------------------------------------------------------

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
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
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
