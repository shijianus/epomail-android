import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/email_provider.dart';
import '../../providers/theme_provider.dart';
import '../../api/api_client.dart';
import '../../models/user_model.dart';
import '../../models/email_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../widgets/letter_avatar.dart';
import '../compose/compose_screen.dart';
import '../detail/detail_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(refresh: true);
      // Server profile is the authority for appearance (parity with web init).
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<ThemeProvider>().applyServer(user.themeMode);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      final accountId = context.read<AccountProvider>().current?.accountId;
      if (accountId != null) {
        _guarded(() => context.read<EmailProvider>().loadMore(accountId));
      }
    }
  }

  Future<void> _load({bool refresh = false, MailFolder? folder}) async {
    final accounts = context.read<AccountProvider>();
    final account = accounts.current;
    if (account == null) return;
    context.read<EmailProvider>().setOwner(
          context.read<AuthProvider>().user?.email ?? '',
          addresses: accounts.accounts.map((a) => a.email),
        );
    await _guarded(() => context.read<EmailProvider>().load(
          accountId: account.accountId,
          folder: folder,
          refresh: refresh,
        ));
    if (mounted) await context.read<AccountProvider>().refreshStats();
  }

  Future<void> _search(String kw) async {
    final account = context.read<AccountProvider>().current;
    if (account == null) return;
    await _guarded(() => context.read<EmailProvider>().load(
          accountId: account.accountId,
          keyword: kw.isEmpty ? null : kw,
          refresh: true,
        ));
  }

  /// Network failures surface as a message instead of an unhandled error.
  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      // A 401 is handled globally (session expiry → sign-in screen).
      if (!e.isAuthError) _notify(e.message);
    } catch (_) {
      _notify('Network error. Pull down to retry.');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openEmail(EmailModel email) {
    if (!email.isRead) {
      context.read<EmailProvider>().markRead(email.emailId).catchError((_) {});
    }
    Navigator.of(context)
        .push(
      MaterialPageRoute(builder: (_) => DetailScreen(email: email)),
    )
        .then((_) {
      if (mounted) {
        context.read<AccountProvider>().refreshStats();
        _load(refresh: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final emailProv = context.watch<EmailProvider>();
    final accountProv = context.watch<AccountProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _Drawer(
        user: auth.user,
        accounts: accountProv.accounts,
        current: accountProv.current,
        stats: accountProv.stats,
        activeFolder: emailProv.folder,
        onFolder: (f) {
          Navigator.pop(context);
          _load(folder: f, refresh: true);
        },
        onLabel: (label) {
          Navigator.pop(context);
          context.read<EmailProvider>().setLabelFilter(label);
          _search('label:"$label"');
        },
        onAccount: (a) {
          accountProv.select(a);
          _load(refresh: true);
        },
        onSettings: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      appBar: _searching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _searching = false;
                    _searchCtrl.clear();
                  });
                  context.read<EmailProvider>().setLabelFilter(null);
                  _load(refresh: true);
                },
              ),
              title: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search emails…',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) {
                  if (v.isEmpty) _load(refresh: true);
                },
                onSubmitted: _search,
              ),
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(emailProv.folder.label),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _searching = true),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: LetterAvatar(
                      name: auth.user?.displayName ?? '?',
                      size: 34,
                      seed: auth.user?.email ?? '',
                    ),
                  ),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: emailProv.loading && emailProv.emails.isEmpty
            ? _buildShimmer()
            : emailProv.folder == MailFolder.drafts
                ? _buildDrafts(emailProv)
                : emailProv.emails.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: emailProv.emails.length +
                            (emailProv.loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= emailProv.emails.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          final email = emailProv.emails[i];
                          return _EmailRow(
                            email: email,
                            onTap: () => _openEmail(email),
                            onStar: () => emailProv.toggleStar(email),
                            onDelete: () =>
                                emailProv.deleteEmail(email.emailId),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ComposeScreen()),
        ),
        tooltip: 'Compose',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, __) => const _ShimmerRow(),
    );
  }

  /// Drafts are client-local (web parity) — rendered from LocalDraft store.
  Widget _buildDrafts(EmailProvider prov) {
    if (prov.drafts.isEmpty) return _buildEmpty();
    return ListView.builder(
      itemCount: prov.drafts.length,
      itemBuilder: (ctx, i) {
        final d = prov.drafts[i];
        return ListTile(
          leading: const Icon(Icons.drafts_outlined, color: AppTheme.blue),
          title: Text(
            d.subject.isEmpty ? '(No Subject)' : d.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'To: ${d.to.isEmpty ? '—' : d.to}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => prov.deleteDraft(d.id),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ComposeScreen(
                draftId: d.id,
                to: [d.to],
                subject: d.subject,
                initialBody: d.content,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.18),
          ),
          const SizedBox(height: 16),
          Text(
            'No emails here',
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

// ─── Email Row ──────────────────────────────────────────────────────────────

class _EmailRow extends StatelessWidget {
  final EmailModel email;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onDelete;

  const _EmailRow({
    required this.email,
    required this.onTap,
    required this.onStar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadBg = AppTheme.blue.withOpacity(isDark ? 0.07 : 0.05);

    return Dismissible(
      key: Key(email.emailId),
      background: const _SwipeBg(
        color: AppTheme.red,
        icon: Icons.delete_outline,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBg(
        color: email.isStar ? Colors.grey : AppTheme.amber,
        icon: email.isStar ? Icons.star_border : Icons.star_outline,
        alignment: Alignment.centerRight,
      ),
      onDismissed: (dir) =>
          dir == DismissDirection.startToEnd ? onDelete() : onStar(),
      confirmDismiss: (_) async => true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: email.isRead ? Colors.transparent : unreadBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: LetterAvatar(
                  name: email.correspondentLabel,
                  seed: email.correspondentAddress,
                  size: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  email.correspondentLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: email.isRead
                                        ? FontWeight.w400
                                        : FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (email.isOfficial) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Official verified',
                                  child: Icon(Icons.verified_rounded,
                                      size: 14, color: AppTheme.blue),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          EpoDate.short(email.createTime),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: email.isRead
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.42)
                                : AppTheme.blue,
                            fontWeight: email.isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            email.subject.isEmpty
                                ? '(No Subject)'
                                : email.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: email.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (email.isStar)
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppTheme.amber),
                        if (email.hasCode)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.key_outlined,
                                size: 13, color: AppTheme.blue),
                          ),
                        if (email.hasAttachments)
                          const Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Icon(Icons.attach_file,
                                size: 13, color: AppTheme.blue),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email.previewText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (!email.isRead) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                      color: AppTheme.blue, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Alignment alignment;
  const _SwipeBg(
      {required this.color, required this.icon, required this.alignment});
  @override
  Widget build(BuildContext context) => Container(
        color: color,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(icon, color: Colors.white, size: 26),
      );
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withOpacity(0.06);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: double.infinity, color: c),
                const SizedBox(height: 8),
                Container(height: 10, width: 180, color: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Navigation Drawer ───────────────────────────────────────────────────────

class _Drawer extends StatelessWidget {
  final UserModel? user;
  final List<AccountModel> accounts;
  final AccountModel? current;
  final SidebarStats stats;
  final MailFolder activeFolder;
  final void Function(MailFolder) onFolder;
  final void Function(String) onLabel;
  final void Function(AccountModel) onAccount;
  final VoidCallback onSettings;

  const _Drawer({
    required this.user,
    required this.accounts,
    required this.current,
    required this.stats,
    required this.activeFolder,
    required this.onFolder,
    required this.onLabel,
    required this.onAccount,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = user?.customLabels ?? const <CustomLabel>[];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  LetterAvatar(
                      name: user?.displayName ?? '?',
                      seed: user?.email ?? '',
                      size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withOpacity(0.5)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 22),
                      onPressed: onSettings),
                ],
              ),
            ),

            // Account switcher
            if (accounts.length > 1)
              ExpansionTile(
                leading: const Icon(Icons.swap_horiz_outlined, size: 20),
                title: Text(current?.email ?? 'Select',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                children: accounts
                    .map((a) => ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          leading: LetterAvatar(
                              name: a.displayLabel, seed: a.email, size: 28),
                          title: Text(a.email,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          selected: a.accountId == current?.accountId,
                          selectedColor: AppTheme.blue,
                          onTap: () => onAccount(a),
                        ))
                    .toList(),
              ),

            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _FolderTile(
                    icon: Icons.inbox_outlined,
                    label: 'Inbox',
                    badge: stats.inboxUnread,
                    active: activeFolder == MailFolder.inbox,
                    onTap: () => onFolder(MailFolder.inbox),
                  ),
                  _FolderTile(
                    icon: Icons.star_outline_rounded,
                    label: 'Starred',
                    active: activeFolder == MailFolder.starred,
                    onTap: () => onFolder(MailFolder.starred),
                  ),
                  _FolderTile(
                    icon: Icons.send_outlined,
                    label: 'Sent',
                    active: activeFolder == MailFolder.sent,
                    onTap: () => onFolder(MailFolder.sent),
                  ),
                  _FolderTile(
                    icon: Icons.drafts_outlined,
                    label: 'Drafts',
                    active: activeFolder == MailFolder.drafts,
                    onTap: () => onFolder(MailFolder.drafts),
                  ),
                  _FolderTile(
                    icon: Icons.alarm_outlined,
                    label: 'Snoozed',
                    badge: stats.snoozedUrgent + stats.snoozedWaiting,
                    active: activeFolder == MailFolder.snoozed,
                    onTap: () => onFolder(MailFolder.snoozed),
                  ),
                  _FolderTile(
                    icon: Icons.all_inbox_outlined,
                    label: 'All Mail',
                    active: activeFolder == MailFolder.all,
                    onTap: () => onFolder(MailFolder.all),
                  ),
                  const Divider(height: 8, indent: 16, endIndent: 16),
                  _FolderTile(
                    icon: Icons.report_gmailerrorred_outlined,
                    label: 'Spam',
                    badge: stats.spamUnread,
                    active: activeFolder == MailFolder.spam,
                    onTap: () => onFolder(MailFolder.spam),
                  ),
                  _FolderTile(
                    icon: Icons.delete_outline,
                    label: 'Trash',
                    active: activeFolder == MailFolder.trash,
                    onTap: () => onFolder(MailFolder.trash),
                  ),
                  if (labels.isNotEmpty) ...[
                    const Divider(height: 8, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        'LABELS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: scheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ),
                    ...labels.map((l) => _LabelTile(
                          label: l,
                          badge: stats.labelUnread[l.name] ?? 0,
                          onTap: () => onLabel(l.name),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _labelColor(String hex) {
  final v = hex.replaceFirst('#', '');
  if (v.length != 6) return AppTheme.blue;
  final value = int.tryParse(v, radix: 16);
  return value == null ? AppTheme.blue : Color(0xFF000000 | value);
}

class _LabelTile extends StatelessWidget {
  final CustomLabel label;
  final int badge;
  final VoidCallback onTap;
  const _LabelTile({required this.label, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<EmailProvider>().labelFilter == label.name;
    return ListTile(
      dense: true,
      leading:
          Icon(Icons.label_outline, color: _labelColor(label.color), size: 20),
      title: Text(
        label.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          color: active ? AppTheme.blue : null,
        ),
      ),
      trailing: badge > 0 ? _Badge(badge) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

class _FolderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final bool active;
  final VoidCallback onTap;
  const _FolderTile({
    required this.icon,
    required this.label,
    this.badge = 0,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(
          icon,
          color: active
              ? AppTheme.blue
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? AppTheme.blue : null,
            fontSize: 15,
          ),
        ),
        trailing: badge > 0 ? _Badge(badge) : null,
        selected: active,
        selectedTileColor: AppTheme.blue.withOpacity(0.09),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onTap,
      );
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: AppTheme.blue, borderRadius: BorderRadius.circular(10)),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}
