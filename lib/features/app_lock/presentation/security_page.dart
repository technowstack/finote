import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pin_repository.dart';

class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key});

  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  final _currentController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  PinStatus? _status;
  int _length = 6;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await ref.read(pinRepositoryProvider).status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _length = status.length;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pengaturan keamanan belum dapat dimuat.'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Coba lagi')),
                ],
              ),
            )
          : status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          status.enabled ? 'Ubah PIN aplikasi' : 'Aktifkan PIN',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PIN mengunci tampilan aplikasi saat dibuka atau kembali dari latar belakang.',
                        ),
                        if (status.enabled) ...[
                          const SizedBox(height: 20),
                          _pinField(
                            controller: _currentController,
                            label: 'PIN saat ini',
                            maxLength: status.length,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 4, label: Text('4 digit')),
                            ButtonSegment(value: 6, label: Text('6 digit')),
                          ],
                          selected: {_length},
                          onSelectionChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  _length = value.single;
                                  _pinController.clear();
                                  _confirmationController.clear();
                                }),
                        ),
                        const SizedBox(height: 12),
                        _pinField(
                          controller: _pinController,
                          label: 'PIN baru',
                          maxLength: _length,
                        ),
                        const SizedBox(height: 12),
                        _pinField(
                          controller: _confirmationController,
                          label: 'Ulangi PIN baru',
                          maxLength: _length,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving
                                ? 'Menyimpan...'
                                : status.enabled
                                ? 'Ubah PIN'
                                : 'Aktifkan PIN',
                          ),
                        ),
                        if (status.enabled) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : _disable,
                            child: const Text('Nonaktifkan PIN'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required int maxLength,
  }) => TextField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: maxLength,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  Future<void> _save() async {
    final status = _status!;
    if (_pinController.text.length != _length ||
        _confirmationController.text != _pinController.text) {
      _message('PIN baru harus sama dan terdiri dari $_length digit.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(pinRepositoryProvider);
      if (status.enabled) {
        final verification = await repository.verify(_currentController.text);
        if (!verification.isSuccess) {
          if (mounted) {
            setState(() => _saving = false);
            _message('PIN saat ini salah atau sedang terkunci.');
          }
          return;
        }
      }
      await repository.setPin(_pinController.text);
      if (!mounted) return;
      _clear();
      setState(() {
        _status = PinStatus(enabled: true, length: _length);
        _saving = false;
      });
      ref.read(pinConfigurationRevisionProvider.notifier).state++;
      _message('PIN berhasil disimpan.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('PIN gagal disimpan. Coba lagi.');
    }
  }

  Future<void> _disable() async {
    if (_currentController.text.isEmpty) {
      _message('Masukkan PIN saat ini untuk menonaktifkan.');
      return;
    }
    setState(() => _saving = true);
    try {
      final disabled = await ref
          .read(pinRepositoryProvider)
          .disable(_currentController.text);
      if (!mounted) return;
      if (!disabled) {
        setState(() => _saving = false);
        _message('PIN saat ini salah atau sedang terkunci.');
        return;
      }
      _clear();
      setState(() {
        _status = const PinStatus(enabled: false, length: 6);
        _length = 6;
        _saving = false;
      });
      ref.read(pinConfigurationRevisionProvider.notifier).state++;
      _message('PIN dinonaktifkan.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('PIN gagal dinonaktifkan. Coba lagi.');
    }
  }

  void _clear() {
    _currentController.clear();
    _pinController.clear();
    _confirmationController.clear();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
