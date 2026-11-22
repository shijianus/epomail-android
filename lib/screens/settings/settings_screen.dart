import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/email_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';
import '../../api/api_client.dart';
import '../../api/auth_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/letter_avatar.dart';
import '../auth/server_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final user = auth.user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // User Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                LetterAvatar(
                  name: user?.displayName ?? '?',
                  seed: user?.email ?? '',
                  size: 52,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                      if (user?.isAdmin == true)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Administrator',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Storage usage (parity with web /settings/data storage meter)
          _StorageCard(),

          const SizedBox(height: 12),

          // Appearance section
          const _SectionHeader(title: 'Appearance'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline),
            ),
            child: ListTile(
              leading: const Icon(Icons.palette_outlined, color: AppTheme.blue),
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(themeProv.themeMode)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _pickTheme(context, themeProv, auth),
            ),
          ),

          const SizedBox(height: 16),

          // Security section
          const _SectionHeader(title: 'Account & Security'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: AppTheme.blue),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _showChangePassword(context),
                ),
                Divider(height: 1, color: scheme.outline),
                ListTile(
                  leading:
                      const Icon(Icons.security_outlined, color: AppTheme.blue),
                  title: const Text('Two-Factor Authentication'),
                  subtitle:
                      Text(user?.totpEnabled == true ? 'Enabled' : 'Disabled'),
                  trailing: Icon(
                    user?.totpEnabled == true
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    color: user?.totpEnabled == true
                        ? AppTheme.green
                        : scheme.onSurface.withOpacity(0.3),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Server section
          const _SectionHeader(title: 'Server Connection'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline),
            ),
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined, color: AppTheme.blue),
              title: const Text('Server URL'),
              subtitle: Text(auth.baseUrl.isNotEmpty ? auth.baseUrl : '—'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServerScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Sign out button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: AppTheme.red, size: 18),
              label:
                  const Text('Sign Out', style: TextStyle(color: AppTheme.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              'EpoCanvas Mail v1.1.0 (Build 2)',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  /// Theme selection syncs to the server profile (PUT /my/updateProfile)
  /// so web & android stay consistent — parity with web themeMode binding.
  Future<void> _pickTheme(
      BuildContext context, ThemeProvider themeProv, AuthProvider auth) async {
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Theme',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.brightness_auto_outlined),
              title: const Text('System Default'),
              trailing: themeProv.themeMode == ThemeMode.system
                  ? const Icon(Icons.check, color: AppTheme.blue)
                  : null,
              onTap: () => Navigator.pop(context, ThemeMode.system),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Light'),
              trailing: themeProv.themeMode == ThemeMode.light
                  ? const Icon(Icons.check, color: AppTheme.blue)
                  : null,
              onTap: () => Navigator.pop(context, ThemeMode.light),
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_outlined),
              title: const Text('Dark'),
              trailing: themeProv.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check, color: AppTheme.blue)
                  : null,
              onTap: () => Navigator.pop(context, ThemeMode.dark),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    await themeProv.set(choice);
    if (auth.isAuthenticated && context.mounted) {
      try {
        await auth.updateProfile({'themeMode': _serialize(choice)});
      } on ApiException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sync failed: ${e.message}'),
            backgroundColor: AppTheme.red));
      } catch (_) {}
    }
  }

  static String _serialize(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'auto';
    }
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!,
                      style:
                          const TextStyle(color: AppTheme.red, fontSize: 13)),
                ),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (newCtrl.text.length < 6) {
                        setState(() =>
                            error = 'Password must be at least 6 characters');
                        return;
                      }
                      if (newCtrl.text != confirmCtrl.text) {
                        setState(() => error = 'Passwords do not match');
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        // Backend contract: PUT /my/resetPassword { password }.
                        await context
                            .read<AuthProvider>()
                            .changePassword(newCtrl.text);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: AppTheme.green,
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setState(() {
                          busy = false;
                          error = e.message;
                        });
                      } catch (_) {
                        setState(() {
                          busy = false;
                          error =
                              'Failed to change password. Please try again.';
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content:
            const Text('Are you sure you want to sign out from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Sign Out', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        context.read<AccountProvider>().clear();
        context.read<EmailProvider>().clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ServerScreen()),
          (_) => false,
        );
      }
    }
  }
}

/// Storage usage card — GET /my/storage (usedMb / quotaMb / isVisitor).
class _StorageCard extends StatefulWidget {
  @override
  State<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<_StorageCard> {
  StorageUsage? _usage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await AuthApi().storage();
      if (!mounted) return;
      setState(() => _usage = StorageUsage.fromJson(raw));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usage = _usage;
    final quotaLabel = usage == null
        ? '…'
        : usage.quotaMb <= 0
            ? '0 MB'
            : '${usage.quotaMb} MB';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_outlined,
                  color: AppTheme.blue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Storage Usage',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Text(
                usage == null
                    ? (_error ?? '—')
                    : '${usage.usedMb} MB / $quotaLabel',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: usage == null || usage.quotaMb <= 0
                ? 0
                : (usage.usedPercentage / 100).clamp(0.0, 1.0),
            backgroundColor: scheme.onSurface.withOpacity(0.08),
            color: (usage?.isExceeded ?? false) ? AppTheme.red : AppTheme.blue,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          if (usage != null && usage.quotaMb <= 0) ...[
            const SizedBox(height: 8),
            Text(
              usage.isVisitor
                  ? 'Visitor accounts have 0 MB storage — only the official welcome email can be received.'
                  : 'No storage quota allocated for this account.',
              style: TextStyle(
                  fontSize: 11.5, color: scheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        ),
      ),
    );
  }
}
