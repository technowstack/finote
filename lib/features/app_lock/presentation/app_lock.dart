import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pin_repository.dart';

class AppLock extends ConsumerStatefulWidget {
  const AppLock({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> with WidgetsBindingObserver {
  PinStatus? _status;
  Object? _error;
  bool _locked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_status?.enabled != true) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      setState(() => _locked = true);
    }
  }

  Future<void> _load() async {
    try {
      final status = await ref.read(pinRepositoryProvider).status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _locked = status.enabled;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pinConfigurationRevisionProvider, (previous, next) => _load());
    if (_error != null) {
      return _LockMessage(
        message: 'Keamanan aplikasi belum dapat dibuka.',
        onRetry: _load,
      );
    }
    final status = _status;
    if (status == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (status.enabled && _locked) {
      return _UnlockPage(
        length: status.length,
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return widget.child;
  }
}

class _UnlockPage extends ConsumerStatefulWidget {
  const _UnlockPage({required this.length, required this.onUnlocked});

  final int length;
  final VoidCallback onUnlocked;

  @override
  ConsumerState<_UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<_UnlockPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    'Buka Catatan Keuangan',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
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
  }

  Future<void> _verify() async {
    if (_controller.text.length != widget.length) {
      setState(() => _error = 'Masukkan PIN ${widget.length} digit.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
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
