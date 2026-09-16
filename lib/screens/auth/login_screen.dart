import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import 'server_screen.dart';
import 'totp_screen.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await context.read<AuthProvider>().login(
            _emailCtrl.text.trim(),
            _pwdCtrl.text,
          );
      if (!mounted) return;
      if (done) {
        await context.read<AccountProvider>().load();
        if (!mounted) return;
        await context.read<AccountProvider>().refreshStats();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TotpScreen()),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Login failed. Please verify credentials.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final serverTitle =
        auth.serverConfig?['title']?.toString() ?? 'EpoCanvas Mail';
    final currentHost = Uri.tryParse(auth.baseUrl)?.host ?? auth.baseUrl;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        size: 40, color: AppTheme.blue),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  serverTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_done_outlined,
                        size: 14, color: AppTheme.green),
                    const SizedBox(width: 6),
                    Text(
                      currentHost,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
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
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
                    if (!v.contains('@')) return 'Invalid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
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
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Sign In',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                // Register entry — hidden when the server closes registration
                // (websiteConfig.register: 0 = open, 1 = closed).
                if (auth.serverConfig == null ||
                    (auth.serverConfig!['register'] is num
                        ? (auth.serverConfig!['register'] as num).toInt() == 0
                        : true))
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      icon:
                          const Icon(Icons.person_add_alt_1_outlined, size: 16),
                      label: const Text('Create a new account',
                          style: TextStyle(fontSize: 13)),
                      style:
                          TextButton.styleFrom(foregroundColor: AppTheme.blue),
                    ),
                  ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ServerScreen()),
                    ),
                    icon: const Icon(Icons.tune_outlined, size: 15),
                    label: const Text('Custom Server Settings',
                        style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurface.withOpacity(0.45)),
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
