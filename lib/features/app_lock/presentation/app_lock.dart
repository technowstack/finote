import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/biometric_lock.dart';
import '../data/pin_repository.dart';

class AppLock extends ConsumerStatefulWidget {
  const AppLock({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLockControllerProvider.notifier).handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pinConfigurationRevisionProvider, (_, _) {
      ref.read(appLockControllerProvider.notifier).load();
    });
    final lock = ref.watch(appLockControllerProvider);
    if (!lock.initialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (lock.error != null && !lock.protectionEnabled) {
      return _LockMessage(
        message: lock.error!,
        onRetry: () => ref.read(appLockControllerProvider.notifier).load(),
      );
    }
    if (!lock.locked) return widget.child;

    if (lock.biometricEnabled) {
      return _BiometricUnlockPage(
        authenticating: lock.authenticating,
        error: lock.error,
        onUnlock: () =>
            ref.read(appLockControllerProvider.notifier).authenticate(),
      );
    }
    return _PinUnlockPage(
      length: lock.pinLength,
      onUnlocked: () =>
          ref.read(appLockControllerProvider.notifier).markPinUnlocked(),
    );
  }
}

class _BiometricUnlockPage extends StatelessWidget {
  const _BiometricUnlockPage({
    required this.authenticating,
    required this.error,
    required this.onUnlock,
  });

  final bool authenticating;
  final String? error;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Kunci Aplikasi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gunakan biometrik untuk membuka Finote.',
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: authenticating ? null : onUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    authenticating ? 'Memeriksa...' : 'Buka dengan Biometrik',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PinUnlockPage extends ConsumerStatefulWidget {
  const _PinUnlockPage({required this.length, required this.onUnlocked});

  final int length;
  final VoidCallback onUnlocked;

  @override
  ConsumerState<_PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends ConsumerState<_PinUnlockPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Buka Finote',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'PIN ${widget.length} digit',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checking ? null : _verify,
                    child: Text(_checking ? 'Memeriksa...' : 'Buka'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _verify() async {
    if (_controller.text.length != widget.length) {
      setState(() => _error = 'Masukkan PIN ${widget.length} digit.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(pinRepositoryProvider)
          .verify(_controller.text);
      if (!mounted) return;
      if (result.isSuccess) {
        widget.onUnlocked();
        return;
      }
      _controller.clear();
      setState(() {
        _checking = false;
        _error = result.lockDuration == null
            ? 'PIN salah.'
            : 'Terlalu banyak percobaan. Coba lagi dalam 30 detik.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'Keamanan aplikasi belum dapat diverifikasi. Coba lagi.';
        });
      }
    }
  }
}

class _LockMessage extends StatelessWidget {
  const _LockMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}
