import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/theme/finote_colors.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/finote_list_tile.dart';
import '../../app_lock/data/biometric_lock.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../market/data/portfolio_market_quotes_provider.dart';
import '../data/reset_data_service.dart';

/// Settings hub page that links to Accounts, Categories, Backup, Legacy Import,
/// Security screens, and display preferences.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).finote.categories;
    final lock = ref.watch(appLockControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          FinoteListSection(
            title: 'Data',
            children: [
              FinoteListTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Akun & Dompet',
                onTap: () => context.push('/accounts'),
              ),
              FinoteListTile(
                icon: Icons.sell_outlined,
                title: 'Kategori',
                onTap: () => context.push('/categories'),
              ),
              FinoteListTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Backup & Restore',
                onTap: () => context.push('/backup'),
              ),
              FinoteListTile(
                icon: Icons.download_outlined,
                title: 'Import data lama',
                onTap: () => context.push('/legacy-import'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Destructive action sits on its own surface, away from routine
          // navigation, and always points the user to Backup first.
          const FinoteListSection(children: [_ResetDataTile()]),
          FinoteListSection(title: 'Tampilan', children: [_ThemeTile()]),
          FinoteListSection(
            title: 'Keamanan',
            children: [
              FinoteListTile(
                icon: Icons.lock_outline,
                title: 'PIN & Biometrik',
                value: lock.initialized
                    ? (lock.protectionEnabled ? 'Aktif' : 'Nonaktif')
                    : null,
                tone: palette[FinoteCategory.bills],
                onTap: () => context.push('/security'),
              ),
            ],
          ),
          FinoteListSection(
            title: 'Tentang',
            children: [
              FinoteListTile(
                icon: Icons.info_outline,
                title: 'Tentang Finote',
                value: 'v1.4.0',
                tone: palette[FinoteCategory.fun],
                onTap: () async {
                  final Uri url = Uri.parse(
                    'https://github.com/technowstack/finote/releases',
                  );

                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw Exception('Tidak dapat membuka $url');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResetDataTile extends ConsumerStatefulWidget {
  const _ResetDataTile();

  @override
  ConsumerState<_ResetDataTile> createState() => _ResetDataTileState();
}

class _ResetDataTileState extends ConsumerState<_ResetDataTile> {
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    return FinoteListTile(
      icon: Icons.delete_outline,
      title: 'Reset data',
      subtitle: 'Hapus seluruh data keuangan dan portofolio. Backup dulu.',
      destructive: true,
      trailing: _resetting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _resetting ? null : _confirmReset,
    );
  }

  Future<void> _confirmReset() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset semua data?'),
        content: const Text(
          'Semua transaksi, akun, transfer, kategori, dan portofolio akan dihapus. '
          'Pastikan sudah memiliki backup jika ingin memulihkannya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi terakhir'),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan tanpa backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset data'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() => _resetting = true);
    try {
      ref.invalidate(portfolioMarketQuotesProvider);
      await ref.read(resetDataServiceProvider).reset();
      if (!mounted) return;
      showAppSnackBar(context, 'Data berhasil direset.');
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'Gagal mereset data. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
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

    return FinoteListTile(
      icon: Icons.dark_mode_outlined,
      title: 'Tema',
      value: _themeLabel(currentMode),
      tone: Theme.of(context).finote.categories[FinoteCategory.shopping],
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
    final colors = Theme.of(context).colorScheme;
    final f = Theme.of(context).finote;
    return AlertDialog(
      title: const Text('Tema'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
        0,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One row per mode. The selected row takes the brand's container
          // color and a check; the choice applies and closes immediately.
          for (final mode in ThemeMode.values)
            Semantics(
              button: true,
              selected: _selected == mode,
              child: Material(
                color: _selected == mode
                    ? colors.primaryContainer
                    : Colors.transparent,
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  borderRadius: AppRadius.mdAll,
                  onTap: () {
                    setState(() => _selected = mode);
                    Navigator.pop(context, mode);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _label(mode),
                              style: AppTypography.labelLg.copyWith(
                                color: _selected == mode
                                    ? colors.onPrimaryContainer
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                          if (_selected == mode)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            )
                          else
                            Icon(Icons.circle_outlined, color: f.outline),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
