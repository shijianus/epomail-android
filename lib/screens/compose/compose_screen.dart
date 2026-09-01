import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/email_provider.dart';
import '../../providers/account_provider.dart';
import '../../api/api_client.dart';
import '../../theme/app_theme.dart';

class ComposeScreen extends StatefulWidget {
  final List<String>? to;
  final String? subject;
  final String? quotedHtml;
  final String? quotedSender;
  final String? quotedTime;

  const ComposeScreen({
    super.key,
    this.to,
    this.subject,
    this.quotedHtml,
    this.quotedSender,
    this.quotedTime,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  final _bccCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _showCcBcc = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.to != null && widget.to!.isNotEmpty) {
      _toCtrl.text = widget.to!.join(', ');
    }
    if (widget.subject != null) {
      _subjectCtrl.text = widget.subject!;
    }
    if (widget.quotedHtml != null && widget.quotedHtml!.isNotEmpty) {
      final cleanQuote = _stripHtml(widget.quotedHtml!);
      _bodyCtrl.text = '\n\n--- On ${widget.quotedTime ?? "earlier"}, ${widget.quotedSender ?? "Sender"} wrote ---\n$cleanQuote';
    }
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _ccCtrl.dispose();
    _bccCtrl.dispose();
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
      await context.read<EmailProvider>().send(
            accountId: account.accountId,
            to: toList,
            cc: _parseEmails(_ccCtrl.text),
            bcc: _parseEmails(_bccCtrl.text),
            subject: _subjectCtrl.text.trim().isEmpty ? '(No Subject)' : _subjectCtrl.text.trim(),
            content: _bodyCtrl.text.trim(),
          );

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

  Future<bool> _confirmDiscard() async {
    if (_toCtrl.text.isEmpty && _subjectCtrl.text.isEmpty && _bodyCtrl.text.isEmpty) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text('Your message has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    return discard ?? false;
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
          title: const Text('Compose'),
          actions: [
            TextButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blue),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.red.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppTheme.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      child: Row(
                        children: [
                          Text('From', style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 13)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              account?.displayLabel ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // To Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      child: Row(
                        children: [
                          Text('To', style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 13)),
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
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(_showCcBcc ? Icons.expand_less : Icons.expand_more, size: 20),
                            onPressed: () => setState(() => _showCcBcc = !_showCcBcc),
                          ),
                        ],
                      ),
                    ),
                    if (_showCcBcc) ...[
                      // CC Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: scheme.outline)),
                        ),
                        child: Row(
                          children: [
                            Text('Cc', style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 13)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _ccCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // BCC Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: scheme.outline)),
                        ),
                        child: Row(
                          children: [
                            Text('Bcc', style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 13)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _bccCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Subject Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: scheme.outline)),
                      ),
                      child: Row(
                        children: [
                          Text('Subject', style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 13)),
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
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
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
