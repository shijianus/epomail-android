import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    final url = context.read<AuthProvider>().baseUrl ?? '';
    if (url.isNotEmpty) _ctrl.text = url;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _connect() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) { setState(() => _error = 'Please enter server URL'); return; }
    setState(() { _busy = true; _error = null; _config = null; });
    try {
      final cfg = await context.read<AuthProvider>().connectServer(url);
      setState(() { _config = cfg; _busy = false; });
    } catch (e) {
      setState(() { _error = 'Cannot connect. Check the URL and try again.'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mark_email_unread_outlined, size: 30, color: AppTheme.blue),
              ),
              const SizedBox(height: 24),
              Text('Connect to Server', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Enter your EpoCanvas Mail server address.',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
              ),
              const SizedBox(height: 36),

              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://mail.example.com',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: _error,
                ),
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _connect,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Connect'),
                ),
              ),

              if (_config != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.green),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_config!['title']?.toString() ?? 'EpoCanvas Mail',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.green)),
                      Text('Server connected successfully',
                          style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
                    ])),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Continue to Login'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
