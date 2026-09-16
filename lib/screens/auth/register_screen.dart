import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

/// Registration screen — parity with the web register page:
/// - register: 0 = open, 1 = closed
/// - regKey:   0 = required, 1 = disabled, 2 = optional
/// - domainList: selectable email domains
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _prefixCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  final _regKeyCtrl = TextEditingController();

  String _domain = '';
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  List<String> get _domains {
    final raw = context.read<AuthProvider>().serverConfig?['domainList'];
    if (raw is List)
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  int get _regKeyMode {
    final v = context.read<AuthProvider>().serverConfig?['regKey'];
    return (v is num) ? v.toInt() : 2; // default optional
  }

  bool get _registerOpen {
    final v = context.read<AuthProvider>().serverConfig?['register'];
    return v == null || (v is num ? v.toInt() : 0) == 0; // default open
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Refresh config in case it wasn't fetched yet.
      final auth = context.read<AuthProvider>();
      try {
        await auth.connectServer(auth.baseUrl);
      } catch (_) {}
      if (mounted) {
        setState(() {
          if (_domains.isNotEmpty) _domain = _domains.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    _regKeyCtrl.dispose();
    super.dispose();
  }

  String get _email => '${_prefixCtrl.text.trim()}@$_domain';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register(
            _email,
            _pwdCtrl.text,
            regKey: _regKeyMode == 0 ||
                    (_regKeyMode == 2 && _regKeyCtrl.text.isNotEmpty)
                ? _regKeyCtrl.text.trim()
                : null,
          );
      if (!mounted) return;
      await context.read<AccountProvider>().load();
      if (!mounted) return;
      await context.read<AccountProvider>().refreshStats();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final domains = _domains;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_registerOpen) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppTheme.amber.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Registration is currently closed on this server.',
                      style: TextStyle(
                          color: AppTheme.amber, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppTheme.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
                // Email prefix + domain picker
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _prefixCtrl,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email prefix',
                          prefixIcon: Icon(Icons.alternate_email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Prefix is required';
                          if (v.contains('@')) return 'Enter prefix only';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: _domain.isNotEmpty ? _domain : null,
                        decoration: const InputDecoration(
                          labelText: 'Domain',
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                        items: domains
                            .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _domain = v ?? ''),
                        validator: (v) => domains.isEmpty
                            ? null
                            : (v == null ? 'Pick a domain' : null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pwd2Ctrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v != _pwdCtrl.text ? 'Passwords do not match' : null,
                ),
                if (_regKeyMode == 0 || _regKeyMode == 2) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _regKeyCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _regKeyMode == 0
                          ? 'Registration Key (required)'
                          : 'Registration Key (optional)',
                      prefixIcon: const Icon(Icons.key_outlined),
                    ),
                    validator: (v) =>
                        _regKeyMode == 0 && (v == null || v.trim().isEmpty)
                            ? 'Registration key is required'
                            : null,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (!_registerOpen || _busy) ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurface.withOpacity(0.55)),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
