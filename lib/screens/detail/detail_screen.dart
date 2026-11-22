import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/email_model.dart';
import '../../providers/email_provider.dart';
import '../../providers/auth_provider.dart';
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/email_html.dart';
import '../../widgets/letter_avatar.dart';
import '../compose/compose_screen.dart';

class DetailScreen extends StatefulWidget {
  final EmailModel email;
  const DetailScreen({super.key, required this.email});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late EmailModel _email;
  bool _translating = false;
  TranslateResult? _translation;
  bool _showTranslation = false;
  String _targetLang = 'zh';
  // Remote images double as tracking pixels; load them only on request.
  bool _showRemoteImages = false;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    // Keep in sync with provider updates (star/labels toggled from outside).
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromProvider());
  }

  void _syncFromProvider() {
    final prov = context.read<EmailProvider>();
    final match =
        prov.emails.where((e) => e.emailId == _email.emailId).toList();
    if (match.isNotEmpty && mounted) {
      setState(() => _email = match.first);
    }
  }

  Future<void> _toggleStar() async {
    final prov = context.read<EmailProvider>();
    if (!await _run(() => prov.toggleStar(_email)) || !mounted) return;
    setState(() => _email = _email.copyWith(isStar: !_email.isStar));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move to Trash'),
        content: const Text('Move this email to Trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trash', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final prov = context.read<EmailProvider>();
      if (await _run(() => prov.deleteEmail(_email.emailId)) && mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _reply() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeScreen(
          sendType: 'reply',
          replyEmailId: _email.emailId,
          to: [_email.type == 1 ? _email.toEmail : _email.from],
          subject: _email.subject.startsWith('Re:')
              ? _email.subject
              : 'Re: ${_email.subject}',
          quotedHtml: _email.content,
          quotedSender: _email.correspondentLabel,
          quotedTime: EpoDate.full(_email.createTime),
        ),
      ),
    );
  }

  void _forward() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeScreen(
          sendType: 'forward',
          subject: _email.subject.startsWith('Fwd:')
              ? _email.subject
              : 'Fwd: ${_email.subject}',
          quotedHtml: _email.content,
          quotedSender: _email.correspondentLabel,
          quotedTime: EpoDate.full(_email.createTime),
        ),
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _restore() async {
    final prov = context.read<EmailProvider>();
    if (await _run(() => prov.restore(_email.emailId)) && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _reportNotSpam() async {
    final prov = context.read<EmailProvider>();
    if (await _run(() => prov.reportNotSpam(_email.emailId)) && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _reportSpam() async {
    final prov = context.read<EmailProvider>();
    if (await _run(() => prov.reportSpam(_email.emailId)) && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _markUnread() async {
    final prov = context.read<EmailProvider>();
    if (await _run(() => prov.markUnread(_email.emailId)) && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _snoozeDialog() async {
    final now = DateTime.now();
    final presets = [
      ('Later today', DateTime(now.year, now.month, now.day, 18)),
      ('Tomorrow', DateTime(now.year, now.month, now.day + 1, 9)),
      ('This weekend', _nextWeekend(now)),
      ('Next week', DateTime(now.year, now.month, now.day + 7, 9)),
    ];
    final picked = await showModalBottomSheet<MapEntry<String, DateTime>>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Snooze until…',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...presets.map((p) => ListTile(
                  title: Text(p.$1),
                  subtitle: Text(EpoDate.full(_fmt(p.$2))),
                  onTap: () => Navigator.pop(context, MapEntry(p.$1, p.$2)),
                )),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Pick date & time'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                );
                if (time == null || !context.mounted) return;
                final dt = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute);
                if (dt.isAfter(now)) {
                  Navigator.pop(context, MapEntry('Custom', dt));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final prov = context.read<EmailProvider>();
    final done = await _run(() => prov.snooze(
          _email.emailId,
          _fmt(picked.value),
          _fmt(picked.value.add(const Duration(hours: 24))),
        ));
    if (done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Snoozed until ${EpoDate.full(_fmt(picked.value))}'),
      ));
      Navigator.pop(context);
    }
  }

  DateTime _nextWeekend(DateTime now) {
    final daysUntilSaturday = (6 - now.weekday) % 7;
    return DateTime(now.year, now.month,
        now.day + (daysUntilSaturday == 0 ? 7 : daysUntilSaturday), 9);
  }

  /// Backend snooze format: "YYYY-MM-DD HH:mm:ss" (see mail-vue formatTime).
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  Future<void> _labelDialog() async {
    final all = context.read<AuthProvider>().user?.customLabels ?? const [];
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No labels defined in your account')));
      return;
    }
    final selected = {..._email.labels};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Label as'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: all
                  .map((l) => CheckboxListTile(
                        value: selected.contains(l.name),
                        title: Text(l.name),
                        activeColor: AppTheme.blue,
                        onChanged: (v) => setState(() {
                          v == true
                              ? selected.add(l.name)
                              : selected.remove(l.name);
                        }),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      final prov = context.read<EmailProvider>();
      final done =
          await _run(() => prov.setLabels(_email.emailId, selected.toList()));
      if (done && mounted) {
        setState(() => _email = _email.copyWith(labels: selected.toList()));
      }
    }
  }

  Future<void> _translate() async {
    setState(() => _translating = true);
    try {
      final res =
          await context.read<EmailProvider>().translate(_email, _targetLang);
      if (!mounted) return;
      setState(() {
        _translation = res;
        _showTranslation = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Translation failed: ${e.message}'),
          backgroundColor: AppTheme.red));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Translation unavailable (AI engine disabled?)'),
          backgroundColor: AppTheme.red));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _downloadAttachment(AttachmentModel att) async {
    try {
      final url = await ApiClient.instance.attachmentUrl(att.key);
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    _toast('Unable to open attachment');
  }

  /// Email links are attacker-controlled: only web / mail / phone links are
  /// opened, and the real destination is confirmed first.
  Future<void> _openLink(String? url) async {
    final uri = EmailHtml.safeLink(url);
    if (uri == null) {
      _toast('This link type is blocked');
      return;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Open link?'),
          content: Text(uri.toString(), maxLines: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    _toast('Unable to open link');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs a mailbox action; a failure shows a message instead of being lost.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      if (!e.isAuthError) _toast(e.message);
    } catch (_) {
      _toast('Action failed. Check your connection.');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyHtml = _showTranslation && _translation != null
        ? (_translation!.translatedHtml.isNotEmpty
            ? _translation!.translatedHtml
            : _translation!.translatedText)
        : _email.content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message'),
        actions: [
          IconButton(
            icon: Icon(
              _email.isStar ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _email.isStar ? AppTheme.amber : null,
            ),
            onPressed: _toggleStar,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'spam':
                  await _reportSpam();
                case 'not_spam':
                  await _reportNotSpam();
                case 'restore':
                  await _restore();
                case 'unread':
                  await _markUnread();
                case 'snooze':
                  await _snoozeDialog();
                case 'label':
                  await _labelDialog();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'label',
                  child: ListTile(
                      leading: Icon(Icons.label_outline),
                      title: Text('Label as'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'snooze',
                  child: ListTile(
                      leading: Icon(Icons.alarm_outlined),
                      title: Text('Snooze'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'unread',
                  child: ListTile(
                      leading: Icon(Icons.mark_email_unread_outlined),
                      title: Text('Mark as unread'),
                      contentPadding: EdgeInsets.zero)),
              if (_email.isSpam)
                const PopupMenuItem(
                    value: 'not_spam',
                    child: ListTile(
                        leading: Icon(Icons.report_outlined),
                        title: Text('Report not spam'),
                        contentPadding: EdgeInsets.zero))
              else ...[
                const PopupMenuItem(
                    value: 'spam',
                    child: ListTile(
                        leading: Icon(Icons.report_outlined),
                        title: Text('Report spam'),
                        contentPadding: EdgeInsets.zero)),
              ],
              if (_email.isDel)
                const PopupMenuItem(
                    value: 'restore',
                    child: ListTile(
                        leading: Icon(Icons.restore_outlined),
                        title: Text('Restore to Inbox'),
                        contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject + official badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _email.subject.isEmpty
                              ? '(No Subject)'
                              : _email.subject,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w700, height: 1.35),
                        ),
                      ),
                      if (_email.isOfficial)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 13, color: AppTheme.blue),
                              const SizedBox(width: 4),
                              Text('Official',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.blue)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Labels chips
                  if (_email.labels.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _email.labels
                          .map((l) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(l,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppTheme.blue)),
                              ))
                          .toList(),
                    ),
                  if (_email.labels.isNotEmpty) const SizedBox(height: 14),

                  // Sender meta row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LetterAvatar(
                          name: _email.correspondentLabel,
                          seed: _email.correspondentAddress,
                          size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_email.correspondentLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(
                              _email.type == 1
                                  ? 'To: ${_email.toEmail}'
                                  : '<${_email.from}>',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface.withOpacity(0.5)),
                            ),
                            Text(
                              _email.type == 1
                                  ? 'Sent'
                                  : 'To: ${_email.toEmail}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            EpoDate.full(_email.createTime),
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurface.withOpacity(0.5)),
                          ),
                          if (_email.isSnoozed)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [
                                const Icon(Icons.alarm_outlined,
                                    size: 13, color: AppTheme.amber),
                                const SizedBox(width: 3),
                                Text('Snoozed',
                                    style: TextStyle(
                                        fontSize: 11, color: AppTheme.amber)),
                              ]),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Verification code badge
                  if (_email.hasCode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppTheme.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_outlined,
                              color: AppTheme.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Code: ${_email.code}',
                            style: const TextStyle(
                              color: AppTheme.blue,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 28),

                  // Translation bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.translate,
                            size: 18, color: AppTheme.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _targetLang,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                    value: 'zh',
                                    child: Text('Chinese',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'en',
                                    child: Text('English',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'ja',
                                    child: Text('Japanese',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'ko',
                                    child: Text('Korean',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'fr',
                                    child: Text('French',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'de',
                                    child: Text('German',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'es',
                                    child: Text('Spanish',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: 'ru',
                                    child: Text('Russian',
                                        style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _targetLang = v ?? 'zh'),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _translating ? null : _translate,
                          child: _translating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  _showTranslation
                                      ? 'View original'
                                      : 'Translate',
                                  style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                  if (!_showRemoteImages &&
                      EmailHtml.hasRemoteImages(bodyHtml))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image_not_supported_outlined,
                              size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Remote images are hidden',
                                style: TextStyle(fontSize: 12.5)),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showRemoteImages = true),
                            child: const Text('Show images',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  // HTML body
                  Html(
                    data: bodyHtml.isNotEmpty
                        ? (_showRemoteImages
                            ? bodyHtml
                            : EmailHtml.blockRemoteImages(bodyHtml))
                        : (_email.textBody ?? '(Empty)'),
                    style: {
                      'body': Style(
                        fontSize: FontSize(14),
                        lineHeight: const LineHeight(1.65),
                        color: scheme.onSurface,
                      ),
                      'a': Style(color: AppTheme.blue),
                      'img': Style(width: Width.auto()),
                    },
                    onLinkTap: (url, _, __) => _openLink(url),
                  ),

                  // Attachments
                  if (_email.hasAttachments) ...[
                    const SizedBox(height: 20),
                    Text('Attachments (${_email.attList.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 8),
                    ..._email.attList.map((att) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file_outlined,
                              color: AppTheme.blue),
                          title: Text(att.filename,
                              style: const TextStyle(fontSize: 13.5)),
                          subtitle: Text(att.sizeLabel,
                              style: const TextStyle(fontSize: 11.5)),
                          trailing:
                              const Icon(Icons.download_outlined, size: 20),
                          onTap: () => _downloadAttachment(att),
                        )),
                  ],
                ],
              ),
            ),
          ),

          // Reply / Forward bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reply,
                    icon: const Icon(Icons.reply_outlined, size: 18),
                    label: const Text('Reply'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _forward,
                    icon: const Icon(Icons.forward_outlined, size: 18),
                    label: const Text('Forward'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
