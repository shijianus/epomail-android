import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class TotpScreen extends StatefulWidget {
  const TotpScreen({super.key});

  @override
  State<TotpScreen> createState() => _TotpScreenState();
}

class _TotpScreenState extends State<TotpScreen> {
  final _nodes = List.generate(6, (_) => FocusNode());
  final _ctrls = List.generate(6, (_) => TextEditingController());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().loginTotp(_code);
      if (!mounted) return;
      await context.read<AccountProvider>().load();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
      for (final c in _ctrls) {
        c.clear();
      }
      _nodes[0].requestFocus();
    } catch (_) {
      setState(() {
        _error = 'Verification failed. Try again.';
        _busy = false;
      });
    }
  }

  void _onChanged(String v, int i) {
    if (v.length == 1 && i < 5) {
      _nodes[i + 1].requestFocus();
    }
    if (v.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
    if (_code.length == 6) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-Factor Auth')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_outlined,
                  size: 56, color: AppTheme.blue),
              const SizedBox(height: 20),
              Text(
                'Verification Code',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code from your authenticator app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55)),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => Container(
                    width: 46,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode: _nodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => _onChanged(v, i),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppTheme.red)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Verify',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
