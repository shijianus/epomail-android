import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/email_provider.dart';
import '../../providers/account_provider.dart';
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';

class ComposeScreen extends StatefulWidget {
  /// 'reply' | 'forward' | '' — passed through to POST /email/send.
  final String sendType;
  final String? replyEmailId;
  final String? draftId;
  final List<String>? to;
  final String? subject;
  final String? initialBody;
  final String? quotedHtml;
  final String? quotedSender;
  final String? quotedTime;

  const ComposeScreen({
    super.key,
    this.sendType = '',
    this.replyEmailId,
    this.draftId,
    this.to,
    this.subject,
    this.initialBody,
    this.quotedHtml,
    this.quotedSender,
    this.quotedTime,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _sending = false;
  String? _error;
  String? _draftId;
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    if (widget.to != null && widget.to!.isNotEmpty) {
      _toCtrl.text = widget.to!.join(', ');
    }
    if (widget.subject != null) {
      _subjectCtrl.text = widget.subject!;
    }
    if (widget.initialBody != null && widget.initialBody!.isNotEmpty) {
      _bodyCtrl.text = widget.initialBody!;
    }
    if (widget.quotedHtml != null && widget.quotedHtml!.isNotEmpty) {
      final cleanQuote = _stripHtml(widget.quotedHtml!);
      _bodyCtrl.text =
          '\n\n--- On ${widget.quotedTime ?? "earlier"}, ${widget.quotedSender ?? "Sender"} wrote ---\n$cleanQuote';
    }
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.contains('@'))
        .toList();
  }

  Future<void> _pickAttachments() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res != null && mounted) {
      setState(() => _attachments.addAll(res.files));
    }
  }

  /// Body → minimal HTML with quoted-reply styling (parity with web compose).
  String _buildHtml(String body) {
    final escaped = body
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final lines = escaped.split('\n');
    final buf = StringBuffer();
    var inQuote = false;
    for (final line in lines) {
      final isQuoteLine = line.trimLeft().startsWith('--- On ') ||
          line.trimLeft().startsWith('&gt;');
      if (isQuoteLine && !inQuote) {
        buf.write('<blockquote class="gmail_quote" style="margin:0 0 0 '
            '0.8ex;border-left:1px solid #ccc;padding-left:1ex">');
        inQuote = true;
      }
      buf.write(line.isEmpty ? '<br>' : '$line<br>');
    }
    if (inQuote) buf.write('</blockquote>');
    return '<div dir="ltr">$buf</div>';
  }

  List<Map<String, dynamic>> _attachmentPayload() {
    return _attachments.where((f) => f.path != null).map((f) {
      final bytes = File(f.path!).readAsBytesSync();
      return {
        'content': base64Encode(bytes),
        'filename': f.name,
        'size': bytes.length,
        'contentType': f.name.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'application/octet-stream',
      };
    }).toList();
  }

  Future<void> _send() async {
    final toList = _parseEmails(_toCtrl.text);
    if (toList.isEmpty) {
      setState(() => _error = 'Please enter at least one recipient email.');
      return;
    }

    final account = context.read<AccountProvider>().current;
    if (account == null) {
      setState(() => _error = 'No account selected.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final body = _bodyCtrl.text.trim();
      await context.read<EmailProvider>().send(
            accountId: account.accountId,
            accountName: account.name,
            receiveEmail: toList,
            subject: _subjectCtrl.text.trim().isEmpty
                ? '(No Subject)'
                : _subjectCtrl.text.trim(),
            content: _buildHtml(body.isEmpty ? '(No content)' : body),
            attachments: _attachmentPayload(),
          );

      // Remove the local draft if this send originated from one.
      if (_draftId != null) {
        await context.read<EmailProvider>().deleteDraft(_draftId!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email sent successfully'),
          backgroundColor: AppTheme.green,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to send email. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveDraft() async {
    final account = context.read<AccountProvider>().current;
    if (account == null) return;
    final draft = LocalDraft(
      id: _draftId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      accountId: account.accountId,
      accountEmail: account.email,
      to: _toCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      content: _bodyCtrl.text,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _draftId = draft.id;
    await context.read<EmailProvider>().saveDraft(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Draft saved locally'), backgroundColor: AppTheme.blue));
  }

  Future<bool> _confirmDiscard() async {
    if (_toCtrl.text.isEmpty &&
        _subjectCtrl.text.isEmpty &&
        _bodyCtrl.text.isEmpty) {
      return true;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text('Your message has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'draft'),
            child: const Text('Save Draft',
                style: TextStyle(color: AppTheme.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (action == 'draft') {
      await _saveDraft();
      return true;
    }
    return action == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final account = context.watch<AccountProvider>().current;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _confirmDiscard();
        if (shouldPop) {
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.sendType == 'reply'
              ? 'Reply'
              : widget.sendType == 'forward'
                  ? 'Forward'
                  : 'Compose'),
          actions: [
            IconButton(
              tooltip: 'Save draft',
              icon: const Icon(Icons.save_outlined, size: 20),
              onPressed: _saveDraft,
            ),
            TextButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.blue),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.red.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppTheme.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppTheme.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // From Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      child: Row(
                        children: [
                          Text('From',
                              style: TextStyle(
                                  color: scheme.onSurface.withOpacity(0.5),
                                  fontSize: 13)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              account?.displayLabel ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Attach files',
                            icon: const Icon(Icons.attach_file, size: 20),
                            onPressed: _pickAttachments,
                          ),
                        ],
                      ),
                    ),
                    // To Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      child: Row(
                        children: [
                          Text('To',
                              style: TextStyle(
                                  color: scheme.onSurface.withOpacity(0.5),
                                  fontSize: 13)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _toCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Recipient email address',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Subject Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      child: Row(
                        children: [
                          Text('Subject',
                              style: TextStyle(
                                  color: scheme.onSurface.withOpacity(0.5),
                                  fontSize: 13)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _subjectCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Subject',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Attachments preview
                    if (_attachments.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments
                              .map((f) => Chip(
                                    avatar: const Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 16,
                                        color: AppTheme.blue),
                                    label: Text(f.name,
                                        style: const TextStyle(fontSize: 12)),
                                    onDeleted: () =>
                                        setState(() => _attachments.remove(f)),
                                  ))
                              .toList(),
                        ),
                      ),
                    // Body Area
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _bodyCtrl,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: 'Compose email...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
