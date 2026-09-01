import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/email_model.dart';
import '../../providers/email_provider.dart';
import '../../providers/account_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _email = widget.email;
  }

  Future<void> _toggleStar() async {
    final accountId = context.read<AccountProvider>().current?.accountId ?? '';
    await context.read<EmailProvider>().toggleStar(_email, accountId);
    if (mounted) {
      setState(() => _email = _email.copyWith(isStar: !_email.isStar));
    }
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
      final accountId = context.read<AccountProvider>().current?.accountId ?? '';
      await context.read<EmailProvider>().deleteEmail(_email.emailId, accountId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _reply() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeScreen(
          to: [_email.from],
          subject: _email.subject.startsWith('Re:') ? _email.subject : 'Re: ${_email.subject}',
          quotedHtml: _email.content,
          quotedSender: _email.senderLabel,
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
          subject: 'Fwd: ${_email.subject}',
          quotedHtml: _email.content,
          quotedSender: _email.senderLabel,
          quotedTime: EpoDate.full(_email.createTime),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'spam') {
                final nav = Navigator.of(context);
                final accountId = context.read<AccountProvider>().current?.accountId ?? '';
                final emailProv = context.read<EmailProvider>();
                await emailProv.markSpam(_email.emailId, accountId);
                nav.pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'spam',
                child: ListTile(
                  leading: Icon(Icons.report_outlined),
                  title: Text('Report Spam'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
                  // Subject
                  Text(
                    _email.subject.isEmpty ? '(No Subject)' : _email.subject,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 18),

                  // Sender meta row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LetterAvatar(name: _email.senderLabel, seed: _email.from, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _email.senderLabel,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '<${_email.from}>',
                              style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5)),
                            ),
                            Text(
                              'To: ${_email.to.join(', ')}',
                              style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            EpoDate.full(_email.createTime),
                            style: TextStyle(fontSize: 11.5, color: scheme.onSurface.withOpacity(0.5)),
                          ),
                          if (_email.hasAttachments)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(Icons.attach_file, size: 14, color: AppTheme.blue),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Verification code badge
                  if (_email.hasCode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_outlined, color: AppTheme.blue, size: 18),
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

                  // HTML body
                  Html(
                    data: _email.content.isNotEmpty ? _email.content : (_email.textBody ?? '(Empty)'),
                    style: {
                      'body': Style(
                        fontSize: FontSize(14),
                        lineHeight: const LineHeight(1.65),
                        color: scheme.onSurface,
                      ),
                      'a': Style(color: AppTheme.blue),
                      'img': Style(width: Width.auto()),
                    },
                    onLinkTap: (url, _, __) async {
                      if (url != null) {
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  ),
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
